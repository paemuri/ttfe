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
};

// spawn fills one random empty cell.
fn spawn(g: *game) void = {
	// Lists all coords with zeroes.
	let zeroes_coords: [MAX_GRID_SIZE: size * MAX_GRID_SIZE: size](u8, u8) =
		[(0, 0)...];
	let zeroes_count = 0z;
	for (let i = 0u8; i < g.grid_size; i += 1) {
		for (let j = 0u8; j < g.grid_size; j += 1) {
			if (g.grid[i][j] == 0) {
				zeroes_coords[zeroes_count] = (i, j);
				zeroes_count += 1;
			};
		};
	};
	if (zeroes_count == 0) { return; };

	const (i, j) = zeroes_coords[
		random::u64n(&g.rng, zeroes_count: u64): size];

	// Values to be filled are always 2 and 4. The latter only appearing in
	// a 1/10 chance.
	g.grid[i][j] = if (random::u64n(&g.rng, 10) == 0) 4 else 2;
};

type game = struct {
	grid: [MAX_GRID_SIZE][MAX_GRID_SIZE]u32,
	grid_size: u8,
	score: u32,
	rng: random::random,
};

fn draw(g: *game) void = {
	for (let i = 0u8; i < g.grid_size; i += 1) {
		for (let j = 0u8; j < g.grid_size; j += 1) {
			fmt::printf("{:6}", g.grid[i][j])!;
		};
		fmt::println()!;
	};
	fmt::printfln("\nScore: {}", g.score)!;
};
