mod protocol;
mod tree;
mod widgets;

use std::io::{self, BufRead, Write};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::Duration;

use iced::widget::{container, text};
use iced::{time, Element, Fill, Subscription, Task, Theme};

use protocol::{IncomingMessage, OutgoingEvent};
use tree::Tree;

// ---------------------------------------------------------------------------
// Message
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
enum Message {
    /// A user clicked a button with the given node ID.
    Click(String),
    /// Periodic tick used to drain the inbound channel.
    Tick,
}

// ---------------------------------------------------------------------------
// App state
// ---------------------------------------------------------------------------

struct App {
    tree: Tree,
    receiver: Receiver<StdinEvent>,
    stdin_closed: bool,
}

/// What the stdin reader thread sends back.
#[derive(Debug)]
enum StdinEvent {
    Message(IncomingMessage),
    Closed,
    Warning(String),
}

impl App {
    fn new(receiver: Receiver<StdinEvent>) -> Self {
        Self {
            tree: Tree::new(),
            receiver,
            stdin_closed: false,
        }
    }

    fn update(&mut self, message: Message) -> Task<Message> {
        match message {
            Message::Tick => {
                self.drain_stdin();
                if self.stdin_closed {
                    iced::exit()
                } else {
                    Task::none()
                }
            }
            Message::Click(id) => {
                emit_event(OutgoingEvent::click(id));
                Task::none()
            }
        }
    }

    fn view(&self) -> Element<'_, Message> {
        match self.tree.root() {
            Some(root) => widgets::render(root),
            None => container(text("waiting for snapshot..."))
                .width(Fill)
                .height(Fill)
                .center(Fill)
                .into(),
        }
    }

    fn subscription(&self) -> Subscription<Message> {
        time::every(Duration::from_millis(16)).map(|_| Message::Tick)
    }

    /// Drain all pending messages from the stdin channel and apply them.
    fn drain_stdin(&mut self) {
        loop {
            match self.receiver.try_recv() {
                Ok(StdinEvent::Message(incoming)) => {
                    self.apply(incoming);
                }
                Ok(StdinEvent::Warning(msg)) => {
                    eprintln!("julep_gui: stdin warning: {msg}");
                }
                Ok(StdinEvent::Closed) => {
                    eprintln!("julep_gui: stdin closed -- exiting");
                    self.stdin_closed = true;
                    break;
                }
                Err(mpsc::TryRecvError::Empty) => break,
                Err(mpsc::TryRecvError::Disconnected) => {
                    eprintln!("julep_gui: stdin reader disconnected -- exiting");
                    self.stdin_closed = true;
                    break;
                }
            }
        }
    }

    fn apply(&mut self, message: IncomingMessage) {
        match message {
            IncomingMessage::Snapshot { tree } => {
                eprintln!("julep_gui: snapshot received (root id={})", tree.id);
                self.tree.snapshot(tree);
            }
            IncomingMessage::Patch { ops } => {
                eprintln!(
                    "julep_gui: patch received ({} ops) -- ignored in Phase 0",
                    ops.len()
                );
            }
        }
    }
}

// ---------------------------------------------------------------------------
// stdout event emitter
// ---------------------------------------------------------------------------

fn emit_event(event: OutgoingEvent) {
    match serde_json::to_string(&event) {
        Ok(json) => {
            let stdout = io::stdout();
            let mut handle = stdout.lock();
            if let Err(e) = writeln!(handle, "{json}") {
                eprintln!("julep_gui: failed to write event to stdout: {e}");
            }
            let _ = handle.flush();
        }
        Err(e) => eprintln!("julep_gui: failed to serialize event: {e}"),
    }
}

// ---------------------------------------------------------------------------
// stdin reader thread
// ---------------------------------------------------------------------------

fn spawn_stdin_reader(sender: Sender<StdinEvent>) {
    thread::spawn(move || {
        let stdin = io::stdin();
        let reader = io::BufReader::new(stdin.lock());

        for line in reader.lines() {
            match line {
                Ok(raw) => {
                    let trimmed = raw.trim();
                    if trimmed.is_empty() {
                        continue;
                    }
                    match serde_json::from_str::<IncomingMessage>(trimmed) {
                        Ok(msg) => {
                            if sender.send(StdinEvent::Message(msg)).is_err() {
                                return;
                            }
                        }
                        Err(e) => {
                            let warning = format!("parse error: {e} (input: {trimmed})");
                            if sender.send(StdinEvent::Warning(warning)).is_err() {
                                return;
                            }
                        }
                    }
                }
                Err(e) => {
                    let _ = sender.send(StdinEvent::Warning(format!("read error: {e}")));
                    break;
                }
            }
        }

        let _ = sender.send(StdinEvent::Closed);
    });
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

fn main() -> iced::Result {
    // The boot closure must be `Fn`, but channel setup must only happen once.
    // Use a Mutex<Option<Receiver>> captured in the closure: the first call
    // takes the receiver out; subsequent calls (which iced never makes) get a
    // dummy channel to satisfy the type system.
    use std::sync::Mutex;

    let (tx, rx) = mpsc::channel::<StdinEvent>();
    spawn_stdin_reader(tx);

    let rx_slot: Mutex<Option<Receiver<StdinEvent>>> = Mutex::new(Some(rx));

    iced::application(
        move || {
            let rx = rx_slot
                .lock()
                .expect("rx_slot lock poisoned")
                .take()
                .unwrap_or_else(|| {
                    eprintln!("julep_gui: boot called more than once -- this is a bug");
                    mpsc::channel().1
                });
            App::new(rx)
        },
        App::update,
        App::view,
    )
    .title("Julep")
    .subscription(App::subscription)
    .theme(Theme::Dark)
    .run()
}
