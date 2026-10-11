use strings;

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
