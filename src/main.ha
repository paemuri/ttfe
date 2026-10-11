use fmt;
use os;
use strconv;

def VERSION: str = "0.1.0";
def HELP: str = ""
"Usage: ttfe [OPTION] [size]

Options:
  -h, --help     Print this help and exit
  -v, --version  Print the version and exit

Arguments:
  size  Defines the game's grid size (defaults to 4)";

export fn main() void = {
	let grid_size_opt: (void | u8) = void;

	for (const arg .. os::args[1..]) {
		switch (arg) {
		case "-h", "--help", "help" =>
			fmt::println(HELP)!;
			os::exit(0);
		case "-v", "--version", "version" =>
			fmt::printf("ttfe {}\n", VERSION)!;
			os::exit(0);
		case =>
			if (grid_size_opt is u8) {
				fmt::errorf("unknown argument: {}\nRun `ttfe --help` for usage.\n", arg)!;
				os::exit(1);
			};
			match (strconv::stou8(arg)) {
			case let n: u8 => grid_size_opt = n;
			case =>
				fmt::errorf("unknown argument: {}\nRun `ttfe --help` for usage.\n", arg)!;
				os::exit(1);
			};
		};
	};

	const grid_size: u8 =
		match (grid_size_opt) {
		case void => yield 4;
		case let n: u8 => yield n;
		};
	fmt::printf("{}\n", grid_size)!;
};
