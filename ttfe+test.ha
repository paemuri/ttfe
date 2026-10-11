use math::random;
use strings;

// game_of builds a game from cells listed row by row.
fn game_of(grid_size: u8, cells: []u32) game = {
	let g = game {
		grid_size = grid_size,
		rng = random::init(0),
		...
	};
	const n = grid_size: size;
	for (let i = 0z; i < len(cells); i += 1) {
		g.grid[i / n][i % n] = cells[i];
	};
	return g;
};

fn assert_cells(g: *game, cells: []u32) void = {
	const n = g.grid_size: size;
	for (let i = 0z; i < len(cells); i += 1) {
		assert(g.grid[i / n][i % n] == cells[i], "unexpected cell");
	};
};

@test fn move_left() void = {
	let g = game_of(4, [
		0, 2, 0, 2,
		4, 0, 4, 4,
		2, 2, 2, 2,
		4, 4, 8, 0,
	]);
	assert(move(&g, direction::LEFT));
	assert_cells(&g, [
		4, 0, 0, 0,
		8, 4, 0, 0,
		4, 4, 0, 0,
		8, 8, 0, 0,
	]);
	assert(g.score == 28);
};

@test fn move_right() void = {
	let g = game_of(4, [
		0, 2, 0, 2,
		4, 0, 4, 4,
		2, 2, 2, 2,
		4, 4, 8, 0,
	]);
	assert(move(&g, direction::RIGHT));
	assert_cells(&g, [
		0, 0, 0, 4,
		0, 0, 4, 8,
		0, 0, 4, 4,
		0, 0, 8, 8,
	]);
	assert(g.score == 28);
};

// Same lines as move_left, but as columns.
@test fn move_up() void = {
	let g = game_of(4, [
		0, 4, 2, 4,
		2, 0, 2, 4,
		0, 4, 2, 8,
		2, 4, 2, 0,
	]);
	assert(move(&g, direction::UP));
	assert_cells(&g, [
		4, 8, 4, 8,
		0, 4, 4, 8,
		0, 0, 0, 0,
		0, 0, 0, 0,
	]);
	assert(g.score == 28);
};

@test fn move_down() void = {
	let g = game_of(4, [
		0, 4, 2, 4,
		2, 0, 2, 4,
		0, 4, 2, 8,
		2, 4, 2, 0,
	]);
	assert(move(&g, direction::DOWN));
	assert_cells(&g, [
		0, 0, 0, 0,
		0, 0, 0, 0,
		0, 4, 4, 8,
		4, 8, 4, 8,
	]);
	assert(g.score == 28);
};

@test fn move_without_change() void = {
	let g = game_of(2, [
		2, 4,
		4, 2,
	]);
	assert(!move(&g, direction::LEFT));
	assert(!move(&g, direction::RIGHT));
	assert(!move(&g, direction::UP));
	assert(!move(&g, direction::DOWN));
	assert(g.score == 0);
};

@test fn spawn_fills_the_empty_cell() void = {
	let g = game_of(2, [
		2, 0,
		4, 2,
	]);
	spawn(&g);
	assert(g.grid[0][1] == 2 || g.grid[0][1] == 4);
};

@test fn spawn_leaves_a_full_grid() void = {
	let g = game_of(2, [
		2, 4,
		4, 2,
	]);
	spawn(&g);
	assert_cells(&g, [
		2, 4,
		4, 2,
	]);
};

@test fn new_game_fills_two_cells() void = {
	const g = new_game(4);
	let filled = 0;
	for (let y = 0z; y < 4; y += 1) {
		for (let x = 0z; x < 4; x += 1) {
			if (g.grid[y][x] != 0) { filled += 1; };
		};
	};
	assert(filled == 2);
};

@test fn has_won_at_2048() void = {
	let g = game_of(2, [
		1024, 1024,
		0, 0,
	]);
	assert(!has_won(&g));
	g.grid[1][1] = 2048;
	assert(has_won(&g));
};

@test fn has_moves_cases() void = {
	let g = game_of(2, [
		2, 4,
		4, 2,
	]);
	assert(!has_moves(&g));
	g = game_of(2, [
		2, 4,
		4, 0,
	]);
	assert(has_moves(&g));
	g = game_of(2, [
		2, 4,
		8, 8,
	]);
	assert(has_moves(&g));
	g = game_of(2, [
		2, 4,
		8, 4,
	]);
	assert(has_moves(&g));
};


fn key(s: str) (direction | void) = key_direction(strings::toutf8(s));

@test fn key_direction_keys() void = {
	assert(key("h") as direction == direction::LEFT);
	assert(key("j") as direction == direction::DOWN);
	assert(key("k") as direction == direction::UP);
	assert(key("l") as direction == direction::RIGHT);
	assert(key("\x1b[A") as direction == direction::UP);
	assert(key("\x1b[B") as direction == direction::DOWN);
	assert(key("\x1b[C") as direction == direction::RIGHT);
	assert(key("\x1b[D") as direction == direction::LEFT);
	assert(key("x") is void);
	assert(key("hj") is void);
	assert(key("\x1b[Z") is void);
};
