//! The Backlog Manager playtime tracker. `docs/TRACKER.md` has the concept
//! and the stages; this is the starting point of stage 1.

/// Turns a duration in seconds into text such as `1 h 05 min`.
fn format_duration(seconds: u64) -> String {
    let hours = seconds / 3600;
    let minutes = seconds % 3600 / 60;
    format!("{hours} h {minutes:02} min")
}

fn main() {
    println!("blm-tracker {}", env!("CARGO_PKG_VERSION"));
    println!("A session of {}", format_duration(3900));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn formats_hours_and_minutes() {
        assert_eq!(format_duration(3900), "1 h 05 min");
    }

    #[test]
    fn leaves_out_the_seconds() {
        assert_eq!(format_duration(59), "0 h 00 min");
    }
}
