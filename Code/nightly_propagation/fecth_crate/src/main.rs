extern crate downloader;
extern crate anyhow;
extern crate crossbeam;
extern crate simplelog;
extern crate tar;
extern crate flate2;

mod util;

use simplelog::*;
use std::fs::OpenOptions;
use util::{run, run_imcomplete};

fn main() {
    CombinedLogger::init(vec![
        TermLogger::new(
            LevelFilter::Info,
            simplelog::Config::default(),
            TerminalMode::Mixed,
            ColorChoice::Auto,
        ),
        WriteLogger::new(
            LevelFilter::Warn,
            simplelog::Config::default(),
            OpenOptions::new()
                .read(true)
                .write(true)
                .create(true)
                .append(true)
                .open("./fetch_crates.log")
                .unwrap(),
        ),
    ])
    .unwrap();

    // run(12, "fails")
    run_imcomplete("fails")
}
