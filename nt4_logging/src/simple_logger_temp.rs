use log::{Record, Level, Metadata, SetLoggerError};

pub struct SimpleLogger;

impl log::Log for SimpleLogger {
    fn enabled(&self, metadata: &Metadata) -> bool {
        metadata.level() <= Level::Debug
    }

    fn log(&self, record: &Record) {
        if self.enabled(record.metadata()) {
            super::log_to_file(&format!("{} - {}", record.level(), record.args()));
        }
    }

    fn flush(&self) {}
}

pub static SIMPLE_LOGGER: SimpleLogger = SimpleLogger;
