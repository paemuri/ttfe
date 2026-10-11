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
  let game_size_arg: nullable *u8 = null;

  for (const arg .. os::args[1..]) {
    switch (arg) {
    case "-h", "--help", "help" =>
      fmt::println(HELP)!;
      os::exit(0);
    case "-v", "--version", "version" =>
      fmt::printf("ttfe {}\n", VERSION)!;
      os::exit(0);
    case =>
      if (game_size_arg != null) {
        fmt::errorf("unknown argument: {}\nRun `ttfe --help` for usage.\n", arg)!;
        os::exit(1);
      };
      match (strconv::stou8(arg)) {
      case let n: u8 =>
        game_size_arg = &n;
      case =>
        fmt::errorf("unknown argument: {}\nRun `ttfe --help` for usage.\n", arg)!;
        os::exit(1);
      };
    };
  };

  const game_size: u8 =
    match (game_size_arg) {
    case null =>
      yield 4;
    case let n: *u8 =>
      yield *n;
    };
  fmt::printf("{}\n", game_size)!;
};
