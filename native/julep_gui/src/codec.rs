use serde::de::DeserializeOwned;
use serde::Serialize;
use std::io::{self, BufRead};

/// Wire codec for communication with the host process.
///
/// `Json` uses newline-delimited JSON (JSONL). Each message is a UTF-8 JSON
/// object terminated by `\n`.
///
/// `MsgPack` uses 4-byte big-endian length-prefixed MessagePack. Each message
/// is `[u32 BE length][msgpack payload]`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Codec {
    Json,
    MsgPack,
}

impl Codec {
    /// Encode a value to wire bytes ready to write to stdout.
    ///
    /// - JSON: `serde_json` serialization + trailing `\n`.
    /// - MsgPack: 4-byte BE u32 length prefix + `rmp_serde` named serialization.
    pub fn encode<T: Serialize>(&self, value: &T) -> Result<Vec<u8>, String> {
        match self {
            Codec::Json => {
                let mut bytes =
                    serde_json::to_vec(value).map_err(|e| format!("json encode: {e}"))?;
                bytes.push(b'\n');
                Ok(bytes)
            }
            Codec::MsgPack => {
                let payload =
                    rmp_serde::to_vec_named(value).map_err(|e| format!("msgpack encode: {e}"))?;
                let len = payload.len() as u32;
                let mut bytes = Vec::with_capacity(4 + payload.len());
                bytes.extend_from_slice(&len.to_be_bytes());
                bytes.extend_from_slice(&payload);
                Ok(bytes)
            }
        }
    }

    /// Decode a raw payload (framing already stripped) into a typed value.
    ///
    /// For JSON, `bytes` is the UTF-8 JSON text (without the trailing newline).
    /// For MsgPack, `bytes` is the raw msgpack payload (without the length prefix).
    ///
    /// MsgPack decoding goes through an intermediate `serde_json::Value` because
    /// rmp-serde doesn't reliably support serde's internally-tagged enums
    /// (`#[serde(tag = "type")]`). The JSON deserializer handles tag dispatch
    /// correctly, so we convert msgpack -> Value -> T.
    pub fn decode<T: DeserializeOwned>(&self, bytes: &[u8]) -> Result<T, String> {
        match self {
            Codec::Json => serde_json::from_slice(bytes).map_err(|e| format!("json decode: {e}")),
            Codec::MsgPack => {
                let val: serde_json::Value =
                    rmp_serde::from_slice(bytes).map_err(|e| format!("msgpack decode: {e}"))?;
                serde_json::from_value(val)
                    .map_err(|e| format!("msgpack decode (tag dispatch): {e}"))
            }
        }
    }

    /// Read one framed message from a buffered reader, returning the raw payload.
    ///
    /// - JSON: reads until `\n`, returns the line bytes (without the newline).
    /// - MsgPack: reads a 4-byte BE u32 length, then reads that many bytes.
    ///
    /// Returns `Ok(None)` on EOF (clean shutdown).
    pub fn read_message<R: BufRead>(&self, reader: &mut R) -> io::Result<Option<Vec<u8>>> {
        match self {
            Codec::Json => loop {
                let mut line = String::new();
                let n = reader.read_line(&mut line)?;
                if n == 0 {
                    return Ok(None);
                }
                let trimmed = line.trim();
                if trimmed.is_empty() {
                    continue;
                }
                return Ok(Some(trimmed.as_bytes().to_vec()));
            },
            Codec::MsgPack => {
                let mut len_buf = [0u8; 4];
                match reader.read_exact(&mut len_buf) {
                    Ok(()) => {}
                    Err(e) if e.kind() == io::ErrorKind::UnexpectedEof => return Ok(None),
                    Err(e) => return Err(e),
                }
                let len = u32::from_be_bytes(len_buf) as usize;
                let mut payload = vec![0u8; len];
                reader.read_exact(&mut payload)?;
                Ok(Some(payload))
            }
        }
    }

    /// Detect codec from the first byte of input.
    ///
    /// `{` (0x7B) indicates JSON. Anything else indicates MsgPack (the first
    /// byte of a 4-byte length prefix).
    pub fn detect_from_first_byte(byte: u8) -> Codec {
        if byte == b'{' {
            Codec::Json
        } else {
            Codec::MsgPack
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde::{Deserialize, Serialize};
    use serde_json::json;

    #[derive(Debug, Serialize, Deserialize, PartialEq)]
    struct Simple {
        name: String,
        count: u32,
    }

    #[derive(Debug, Serialize, Deserialize, PartialEq)]
    #[serde(tag = "type", rename_all = "snake_case")]
    enum Tagged {
        Alpha { value: String },
        Beta { x: f64, y: f64 },
    }

    #[derive(Debug, Serialize, Deserialize, PartialEq)]
    struct WithFlatten {
        op: String,
        #[serde(flatten)]
        rest: serde_json::Value,
    }

    // -- JSON roundtrips --

    #[test]
    fn json_roundtrip_simple() {
        let original = Simple {
            name: "test".into(),
            count: 42,
        };
        let bytes = Codec::Json.encode(&original).unwrap();
        assert!(bytes.ends_with(b"\n"));
        let decoded: Simple = Codec::Json.decode(&bytes[..bytes.len() - 1]).unwrap();
        assert_eq!(decoded, original);
    }

    #[test]
    fn json_roundtrip_tagged_enum() {
        let original = Tagged::Beta { x: 1.5, y: 2.5 };
        let bytes = Codec::Json.encode(&original).unwrap();
        let decoded: Tagged = Codec::Json.decode(&bytes[..bytes.len() - 1]).unwrap();
        assert_eq!(decoded, original);
    }

    // -- MsgPack roundtrips --

    #[test]
    fn msgpack_roundtrip_simple() {
        let original = Simple {
            name: "test".into(),
            count: 42,
        };
        let bytes = Codec::MsgPack.encode(&original).unwrap();
        // First 4 bytes are length prefix
        let len = u32::from_be_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]) as usize;
        assert_eq!(len, bytes.len() - 4);
        let decoded: Simple = Codec::MsgPack.decode(&bytes[4..]).unwrap();
        assert_eq!(decoded, original);
    }

    #[test]
    fn msgpack_roundtrip_tagged_enum() {
        let original = Tagged::Alpha {
            value: "hello".into(),
        };
        let bytes = Codec::MsgPack.encode(&original).unwrap();
        let payload = &bytes[4..];
        let decoded: Tagged = Codec::MsgPack.decode(payload).unwrap();
        assert_eq!(decoded, original);
    }

    #[test]
    fn msgpack_roundtrip_tagged_enum_beta() {
        let original = Tagged::Beta { x: 3.14, y: -1.0 };
        let bytes = Codec::MsgPack.encode(&original).unwrap();
        let payload = &bytes[4..];
        let decoded: Tagged = Codec::MsgPack.decode(payload).unwrap();
        assert_eq!(decoded, original);
    }

    #[test]
    fn msgpack_flatten_deserialize() {
        // Flatten on deserialize: encode a map with extra keys, decode into
        // a struct with #[serde(flatten)] rest: Value.
        let input = json!({"op": "props", "path": [0, 1], "props": {"label": "hi"}});
        let bytes = rmp_serde::to_vec_named(&input).unwrap();
        let decoded: WithFlatten = rmp_serde::from_slice(&bytes).unwrap();
        assert_eq!(decoded.op, "props");
        assert_eq!(decoded.rest["path"], json!([0, 1]));
        assert_eq!(decoded.rest["props"]["label"], "hi");
    }

    // -- read_message --

    #[test]
    fn json_read_message_skips_blank_lines() {
        // Blank lines between messages must be skipped, not treated as EOF.
        let data = b"\n\n{\"name\":\"a\",\"count\":1}\n\n{\"name\":\"b\",\"count\":2}\n\n";
        let mut reader = io::BufReader::new(&data[..]);

        let msg1 = Codec::Json.read_message(&mut reader).unwrap().unwrap();
        let s1: Simple = Codec::Json.decode(&msg1).unwrap();
        assert_eq!(s1.name, "a");

        let msg2 = Codec::Json.read_message(&mut reader).unwrap().unwrap();
        let s2: Simple = Codec::Json.decode(&msg2).unwrap();
        assert_eq!(s2.name, "b");

        // Trailing blank lines followed by real EOF should return None.
        assert!(Codec::Json.read_message(&mut reader).unwrap().is_none());
    }

    #[test]
    fn json_read_message() {
        let data = b"{\"name\":\"a\",\"count\":1}\n{\"name\":\"b\",\"count\":2}\n";
        let mut reader = io::BufReader::new(&data[..]);

        let msg1 = Codec::Json.read_message(&mut reader).unwrap().unwrap();
        let s1: Simple = Codec::Json.decode(&msg1).unwrap();
        assert_eq!(s1.name, "a");

        let msg2 = Codec::Json.read_message(&mut reader).unwrap().unwrap();
        let s2: Simple = Codec::Json.decode(&msg2).unwrap();
        assert_eq!(s2.name, "b");

        assert!(Codec::Json.read_message(&mut reader).unwrap().is_none());
    }

    #[test]
    fn msgpack_read_message() {
        // Build two length-prefixed msgpack messages
        let s1 = Simple {
            name: "x".into(),
            count: 10,
        };
        let s2 = Simple {
            name: "y".into(),
            count: 20,
        };
        let p1 = rmp_serde::to_vec_named(&s1).unwrap();
        let p2 = rmp_serde::to_vec_named(&s2).unwrap();

        let mut data = Vec::new();
        data.extend_from_slice(&(p1.len() as u32).to_be_bytes());
        data.extend_from_slice(&p1);
        data.extend_from_slice(&(p2.len() as u32).to_be_bytes());
        data.extend_from_slice(&p2);

        let mut reader = io::BufReader::new(&data[..]);

        let msg1 = Codec::MsgPack.read_message(&mut reader).unwrap().unwrap();
        let d1: Simple = Codec::MsgPack.decode(&msg1).unwrap();
        assert_eq!(d1, s1);

        let msg2 = Codec::MsgPack.read_message(&mut reader).unwrap().unwrap();
        let d2: Simple = Codec::MsgPack.decode(&msg2).unwrap();
        assert_eq!(d2, s2);

        assert!(Codec::MsgPack.read_message(&mut reader).unwrap().is_none());
    }

    // -- Cross-format: simulate external msgpack (e.g. Elixir's Msgpax) --
    //
    // rmp-serde's own serializer produces bytes that its deserializer can
    // roundtrip, but external msgpack producers encode maps differently.
    // These tests build raw msgpack via serde_json::Value -> rmp_serde
    // (which is format-agnostic, not tagged-enum-aware) to simulate what
    // an external producer like Msgpax sends. The Codec::decode workaround
    // (msgpack -> Value -> serde_json::from_value) must handle these.

    #[test]
    fn msgpack_external_tagged_enum_alpha() {
        // Simulate Msgpax encoding {"type": "alpha", "value": "hello"}
        let external = json!({"type": "alpha", "value": "hello"});
        let bytes = rmp_serde::to_vec_named(&external).unwrap();
        let decoded: Tagged = Codec::MsgPack.decode(&bytes).unwrap();
        assert_eq!(
            decoded,
            Tagged::Alpha {
                value: "hello".into()
            }
        );
    }

    #[test]
    fn msgpack_external_tagged_enum_beta() {
        let external = json!({"type": "beta", "x": 1.5, "y": -2.0});
        let bytes = rmp_serde::to_vec_named(&external).unwrap();
        let decoded: Tagged = Codec::MsgPack.decode(&bytes).unwrap();
        assert_eq!(decoded, Tagged::Beta { x: 1.5, y: -2.0 });
    }

    #[test]
    fn msgpack_external_incoming_settings() {
        // This is exactly what Elixir sends: a plain map with "type":"settings".
        use crate::protocol::IncomingMessage;
        let external = json!({"type": "settings", "settings": {"antialiasing": false}});
        let bytes = rmp_serde::to_vec_named(&external).unwrap();
        let decoded: IncomingMessage = Codec::MsgPack.decode(&bytes).unwrap();
        assert!(matches!(decoded, IncomingMessage::Settings { .. }));
    }

    #[test]
    fn msgpack_external_incoming_snapshot() {
        use crate::protocol::IncomingMessage;
        let external = json!({"type": "snapshot", "tree": {"id": "root", "type": "column", "props": {}, "children": []}});
        let bytes = rmp_serde::to_vec_named(&external).unwrap();
        let decoded: IncomingMessage = Codec::MsgPack.decode(&bytes).unwrap();
        assert!(matches!(decoded, IncomingMessage::Snapshot { .. }));
    }

    // -- detect --

    #[test]
    fn detect_json_from_brace() {
        assert_eq!(Codec::detect_from_first_byte(b'{'), Codec::Json);
    }

    #[test]
    fn detect_msgpack_from_zero() {
        assert_eq!(Codec::detect_from_first_byte(0x00), Codec::MsgPack);
    }

    #[test]
    fn detect_msgpack_from_fixmap() {
        assert_eq!(Codec::detect_from_first_byte(0x85), Codec::MsgPack);
    }
}
