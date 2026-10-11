use fmt;
use math::random;
use os;
use strconv;
use time;

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
	draw(&g);

	const moved = move_left(&g);
	if (moved) { spawn(&g);	};
	draw(&g);
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
	for (let y = 0u8; y < g.grid_size; y += 1) {
		for (let x = 0u8; x < g.grid_size; x += 1) {
			fmt::printf("{:6}", g.grid[y][x])!;
		};
		fmt::println()!;
	};
	fmt::printfln("\nScore: {}", g.score)!;
};

fn move_left(g: *game) bool = {
	let moved = false;
	for (let y = 0u8; y < g.grid_size; y += 1) {
		// Will represent the new row, _after_ the movement.
		let row: [MAX_GRID_SIZE]u32 = [0...];
		// Items in row.
		let count = 0u8;
		// Whether last item in row was just merged.
		let merged = false;

		for (let x = 0u8; x < g.grid_size; x += 1) {
			const cell = g.grid[y][x];

			// Ignore zeroes. Game's rules.
			if (cell == 0) {
				continue;
			};

			// If:
			// 1. There are items before
			// 2. The last one has the same value as current one
			// 3. Last one wasn't merged
			// Then merge it. Otherwise, just add to the row and continue.
			if (count > 0 && row[count-1] == cell && !merged) {
				row[count-1] *= 2;
				merged = true;
				g.score += row[count-1];
			} else {
				row[count] = cell;
				count += 1;
				merged = false;
			};
		};

		// Copy moved row into grid.
		for (let x = 0u8; x < g.grid_size; x += 1) {
			if (g.grid[y][x] != row[x]) {
				moved = true;
			};
			g.grid[y][x] = row[x];
		};
	};
	return moved;
};
