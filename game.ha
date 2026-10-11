use math::random;
use time;

type game = struct {
	grid: [MAX_GRID_SIZE][MAX_GRID_SIZE]u32,
	grid_size: u8,
	score: u32,
	rng: random::random,
};

type direction = enum {
	LEFT,
	RIGHT,
	UP,
	DOWN,
};

fn new_game(grid_size: u8) game = {
	const now = time::now(time::clock::REALTIME);
	let g = game {
		grid_size = grid_size,
		rng = random::init(now.sec: u64 ^ now.nsec: u64),
		...
	};
	spawn(&g);
	spawn(&g);
	return g;
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
