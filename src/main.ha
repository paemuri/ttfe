use bufio;
use fmt;
use io;
use math::random;
use os;
use strconv;
use time;
use unix::tty;

def MIN_GRID_SIZE: u8 = 2;
def MAX_GRID_SIZE: u8 = 16;
def DEFAULT_GRID_SIZE: u8 = 4;
def VERSION: str = "0.1.0";
def HELP: str = ""
"Usage: ttfe [OPTION] [grid size]

Options:
  -h, --help     Print this help and exit
  -v, --version  Print the version and exit

Arguments:
  grid size  Defines the game's grid size (min: {}, max: {}, default: {})";

export fn main() void = {
	let grid_size_opt: (void | u8) = void;

	for (const arg .. os::args[1..]) {
		switch (arg) {
		case "-h", "--help", "help" =>
			fmt::printfln(HELP, MIN_GRID_SIZE, MAX_GRID_SIZE,
				DEFAULT_GRID_SIZE)!;
			return;
		case "-v", "--version", "version" =>
			fmt::printfln("ttfe {}", VERSION)!;
			return;
		case =>
			if (grid_size_opt is u8) {
				fail_arg("unknown argument: {}", arg);
			};
			match (strconv::stou8(arg)) {
			case let n: u8 =>
				if (n < MIN_GRID_SIZE || n > MAX_GRID_SIZE) {
					fail_arg("invalid value for "
						"\"grid size\": {}", arg);
				};
				grid_size_opt = n;
			case strconv::overflow =>
				fail_arg("invalid value for \"grid size\": {}",
					arg);
			case =>
				fail_arg("unknown argument: {}", arg);
			};
		};
	};

	const grid_size: u8 = match (grid_size_opt) {
	case void => yield DEFAULT_GRID_SIZE;
	case let n: u8 => yield n;
	};

	run(grid_size);
};

fn fail_arg(fmtstr: str, arg: str) never = {
	fmt::errorfln(fmtstr, arg)!;
	fmt::errorln("Run `ttfe --help` for usage.")!;
	os::exit(1);
};

fn run(grid_size: u8) void = {
	const now = time::now(time::clock::REALTIME);
	let g = game {
		grid_size = grid_size,
		rng = random::init(now.sec: u64 ^ now.nsec: u64),
		...
	};

	spawn(&g);
	spawn(&g);

	let term = tty::termios_query(os::stdin_file)!;
	defer tty::termios_restore(&term);
	tty::makeraw(&term)!;
	// \x1b[?1049h = uses the alternate screen.
	// \x1b[?25l = hides the cursor.
	fmt::print("\x1b[?1049h\x1b[?25l")!;
	defer {
		// \x1b[?25h = shows cursor again.
		// \x1b[?1049l = returns to the normal screen.
		fmt::print("\x1b[?25h\x1b[?1049l")!;
		bufio::flush(os::stdout)!;
	};

	draw(&g);
	let buf: [3]u8 = [0...];
	for (true) {
		const buf_bytes = match (io::read(os::stdin_file, buf[..])!) {
		case let n: size => yield n;
		case io::EOF => break;
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
		draw(&g);
	};
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

// spawn fills one random empty cell.
fn spawn(g: *game) void = {
	// Lists all coords with zeroes.
	let zeroes_coords: [MAX_GRID_SIZE: size * MAX_GRID_SIZE: size](u8, u8) =
		[(0, 0)...];
	let zeroes_count = 0z;
	for (let y = 0u8; y < g.grid_size; y += 1) {
		for (let x = 0u8; x < g.grid_size; x += 1) {
			if (g.grid[y][x] == 0) {
				zeroes_coords[zeroes_count] = (x, y);
				zeroes_count += 1;
			};
		};
	};
	if (zeroes_count == 0) { return; };

	const (x, y) = zeroes_coords[
		random::u64n(&g.rng, zeroes_count: u64): size];

	// Values to be filled are always 2 and 4. The latter only appearing in
	// a 1/10 chance.
	g.grid[y][x] = if (random::u64n(&g.rng, 10) == 0) 4 else 2;
};

type game = struct {
	grid: [MAX_GRID_SIZE][MAX_GRID_SIZE]u32,
	grid_size: u8,
	score: u32,
	rng: random::random,
};

fn draw(g: *game) void = {
	defer bufio::flush(os::stdout)!;

	const grid_size = g.grid_size: size;
	// Each cell is 6 columns wide. Below the grid: the score, a status
	// line, an empty line and the quit hint.
	const width = grid_size * 6;
	const height = grid_size + 4;

	// \x1b[H = clears the screen.
	// \x1b[2J = puts the cursor in the top-left corner.
	fmt::print("\x1b[H\x1b[2J")!;

	const term = tty::winsize(os::stdout_file)!;
	const columns = term.columns: size;
	const rows = term.rows: size;
	if (columns < width || rows < height) {
		fmt::print("Terminal too small.")!;
		return;
	};

	// Center the block, rounding up. Terminal rows and columns start at 1.
	const left = (columns - width + 1) / 2 + 1;
	const top = (rows - height + 1) / 2 + 1;
	const right = left + width;

	for (let y = 0z; y < grid_size; y += 1) {
		goto(top + y, left);
		for (let x = 0z; x < grid_size; x += 1) {
			const value = g.grid[y][x];
			// \x1b[1;38;5;Xm = sets text style, where
			// - 1 = bold
			// - 38;5 = fg color
			// - X = color(value)
			// \x1b[0m = resets to normal
			fmt::printf("\x1b[1;38;5;{}m{:6}\x1b[0m",
				color(value), value)!;
		};
	};

	let score_buf: [32]u8 = [0...];
	const score_text = fmt::bsprintf(score_buf, "Score: {}", g.score)!;
	goto(top + grid_size, right - len(score_text));
	fmt::print(score_text)!;

	let status_text = "";
	if (has_won(g)) {
		status_text = "YOU WON";
	} else if (!has_moves(g)) {
		status_text = "YOU LOST";
	};
	goto(top + grid_size + 1, right - len(status_text));
	// \x1b[1m = sets as bold.
	// \x1b[0m = resets.
	fmt::printf("\x1b[1m{}\x1b[0m", status_text)!;

	const quit_text = "[q]uit";
	goto(top + grid_size + 3, right - len(quit_text));
	fmt::print(quit_text)!;
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
fn goto(row: size, col: size) void = {
	fmt::printf("\x1b[{};{}H", row, col)!;
};

type direction = enum {
	LEFT,
	RIGHT,
	UP,
	DOWN,
};

// cell_at maps i/j into x/y (actual coordinates) and fetches the cell.
fn cell_at(g: *game, i: u8, j: u8, dir: direction) *u32 = {
	const last = g.grid_size - 1;
	// i is the "line" (row for LEFT/RIGHT or column for UP/DOWN) and j the
	// position of the cell inside that line (LEFT/UP is the same as the
	// grid's array, while RIGHT/DOWN is reversed).
	// j represents the position of the cell from the ending point of the
	// movement, e.g. LEFT counts 0 from the left to the right.
	switch (dir) {
	case direction::LEFT =>
		return &g.grid[i][j];
	case direction::RIGHT =>
		return &g.grid[i][last - j];
	case direction::UP =>
		return &g.grid[j][i];
	case direction::DOWN =>
		return &g.grid[last - j][i];
	};
};

fn move(g: *game, dir: direction) bool = {
	let moved = false;
	for (let i = 0u8; i < g.grid_size; i += 1) {
		// Will represent the new line (row for LEFT/RIGHT or column for
		// UP/DOWN) _after_ the movement.
		let line: [MAX_GRID_SIZE]u32 = [0...];
		// Items in line.
		let count = 0u8;
		// Whether last item in line was just merged.
		let merged = false;

		// This iterates the line from the ending point of the movement,
		// e.g. LEFT counts 0 from the left to the right.
		for (let j = 0u8; j < g.grid_size; j += 1) {
			const cell = *cell_at(g, i, j, dir);

			// Skips zeroes. Cells move over them.
			if (cell == 0) {
				continue;
			};

			// If:
			// 1. There are items before
			// 2. The last one has the same value as current one
			// 3. Last one wasn't merged
			// Then merge it. Otherwise, just add to the line.
			if (count > 0 && line[count - 1] == cell && !merged) {
				line[count - 1] *= 2;
				merged = true;
				g.score += line[count - 1];
			} else {
				line[count] = cell;
				count += 1;
				merged = false;
			};
		};

		// Copy moved line into grid.
		for (let j = 0u8; j < g.grid_size; j += 1) {
			const cell = cell_at(g, i, j, dir);
			if (*cell != line[j]) {
				moved = true;
			};
			*cell = line[j];
		};
	};
	return moved;
};

fn has_won(g: *game) bool = {
	for (let y = 0u8; y < g.grid_size; y += 1) {
		for (let x = 0u8; x < g.grid_size; x += 1) {
			if (g.grid[y][x] >= 2048) {
				return true;
			};
		};
	};
	return false;
};

fn has_moves(g: *game) bool = {
	const last = g.grid_size - 1;
	for (let y = 0u8; y < g.grid_size; y += 1) {
		for (let x = 0u8; x < g.grid_size; x += 1) {
			const value = g.grid[y][x];
			// There are moves if there is either an empty cell, or
			// two equal tiles are next to each other.
			if (value == 0) { return true; };
			if (x < last && value == g.grid[y][x + 1]) {
				return true;
			};
			if (y < last && value == g.grid[y + 1][x]) {
				return true;
			};
		};
	};
	return false;
};
