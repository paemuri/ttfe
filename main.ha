use fmt;
use io;
use os;
use strconv;

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

	match (run(grid_size)) {
	case void => void;
	case let err: io::error =>
		fmt::fatalf("ttfe: {}", io::strerror(err));
	};
};

fn fail_arg(fmtstr: str, arg: str) never = {
	fmt::error("ttfe: ")!;
	fmt::errorfln(fmtstr, arg)!;
	fmt::fatal("Run `ttfe --help` for usage.");
};
