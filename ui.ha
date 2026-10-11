use bufio;
use errors;
use fmt;
use io;
use math::random;
use os;
use time;
use unix::signal;
use unix::tty;

fn run(grid_size: u8) (void | io::error) = {
	const now = time::now(time::clock::REALTIME);
	let g = game {
		grid_size = grid_size,
		rng = random::init(now.sec: u64 ^ now.nsec: u64),
		...
	};

	spawn(&g);
	spawn(&g);

	if (!tty::isatty(os::stdin_file) || !tty::isatty(os::stdout_file)) {
		fmt::fatal("ttfe: must run in a terminal");
	};

	let term = tty::termios_query(os::stdin_file)?;
	defer tty::termios_restore(&term);
	tty::makeraw(&term)?;
	// \x1b[?1049h = uses the alternate screen.
	// \x1b[?25l = hides the cursor.
	fmt::print("\x1b[?1049h\x1b[?25l")?;
	defer {
		// \x1b[?25h = shows cursor again.
		// \x1b[?1049l = returns to the normal screen.
		// Errors are ignored: there is nowhere left to report them.
		_ = fmt::print("\x1b[?25h\x1b[?1049l");
		_ = bufio::flush(os::stdout);
	};

	signal::handle(signal::sig::WINCH, &on_resize);

	draw(&g)?;
	let buf: [3]u8 = [0...];
	for (true) {
		if (resized) {
			resized = false;
			draw(&g)?;
		};

		const buf_bytes = match (io::read(os::stdin_file, buf[..])) {
		case let n: size => yield n;
		case io::EOF => break;
		case errors::interrupted => continue;
		case let err: io::error => return err;
		};

		// q or Ctrl-C quits.
		if (buf[0]: rune == 'q' || buf[0] == 0x03) {
			break;
		};

		const dir = match (key_direction(buf[..buf_bytes])) {
		case let d: direction => yield d;
		case void => continue;
		};

		if (move(&g, dir)) { spawn(&g); };
		draw(&g)?;
	};
};

fn draw(g: *game) (void | io::error) = {
	const grid_size = g.grid_size: size;
	// Each cell is 6 columns wide. Below the grid: the score, a status
	// line, an empty line and the quit hint.
	const width = grid_size * 6;
	const height = grid_size + 4;

	// \x1b[H = puts the cursor in the top-left corner.
	// \x1b[2J = clears the screen.
	fmt::print("\x1b[H\x1b[2J")?;

	const term = tty::winsize(os::stdout_file)?;
	const columns = term.columns: size;
	const rows = term.rows: size;
	if (columns < width || rows < height) {
		fmt::print("Terminal too small.")?;
		bufio::flush(os::stdout)?;
		return;
	};

	// Center the block, rounding up. Terminal rows and columns start at 1.
	const left = (columns - width + 1) / 2 + 1;
	const top = (rows - height + 1) / 2 + 1;
	const right = left + width;

	for (let y = 0z; y < grid_size; y += 1) {
		goto(top + y, left)?;
		for (let x = 0z; x < grid_size; x += 1) {
			const value = g.grid[y][x];
			// \x1b[1;38;5;Xm = sets text style, where
			// - 1 = bold
			// - 38;5 = fg color
			// - X = color(value)
			// \x1b[0m = resets to normal
			fmt::printf("\x1b[1;38;5;{}m{:6}\x1b[0m",
				color(value), value)?;
		};
	};

	let score_buf: [32]u8 = [0...];
	// Can't fail: "Score: " and a u32 need at most 17 bytes.
	const score_text = fmt::bsprintf(score_buf, "Score: {}", g.score)!;
	goto(top + grid_size, right - len(score_text))?;
	fmt::print(score_text)?;

	let status_text = "";
	if (has_won(g)) {
		status_text = "YOU WON";
	} else if (!has_moves(g)) {
		status_text = "YOU LOST";
	};
	goto(top + grid_size + 1, right - len(status_text))?;
	// \x1b[1m = sets as bold.
	// \x1b[0m = resets.
	fmt::printf("\x1b[1m{}\x1b[0m", status_text)?;

	const quit_text = "[q]uit";
	goto(top + grid_size + 3, right - len(quit_text))?;
	fmt::print(quit_text)?;
	bufio::flush(os::stdout)?;
};

fn key_direction(key: []u8) (direction | void) = {
	if (len(key) == 1) {
		switch (key[0]: rune) {
		case 'h' => return direction::LEFT;
		case 'j' => return direction::DOWN;
		case 'k' => return direction::UP;
		case 'l' => return direction::RIGHT;
		case => return;
		};
	};

	// Arrow keys are 3 bytes: Esc, '[' and a letter.
	if (len(key) == 3 && key[0] == 0x1b && key[1]: rune == '[') {
		switch (key[2]: rune) {
		case 'A' => return direction::UP;
		case 'B' => return direction::DOWN;
		case 'C' => return direction::RIGHT;
		case 'D' => return direction::LEFT;
		case => return;
		};
	};
};

fn color(value: u32) u8 = {
	switch (value) {
	case 0 => return 247; // grey
	case 2 => return 202; // orange-red
	case 4 => return 214; // orange
	case 8 => return 226; // yellow
	case 16 => return 40; // green
	case 32 => return 47; // spring green
	case 64 => return 14; // bright cyan
	case 128 => return 33; // dodger blue
	case 256 => return 141; // medium purple
	case 512 => return 213; // orchid
	case 1024 => return 201; // magenta
	case => return 231; // white
	};
};

// goto moves the cursor to the given row and column, both starting at 1.
fn goto(row: size, col: size) (void | io::error) = {
	fmt::printf("\x1b[{};{}H", row, col)?;
};

// Set by the SIGWINCH handler, cleared by the main loop.
let resized: bool = false;

fn on_resize(
	_sig: signal::sig,
	_info: *signal::siginfo,
	_uctx: *opaque,
) void = {
	resized = true;
};
