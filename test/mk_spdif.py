samples = [
	('Z', 0x7a6ef6), ('Y', 0x5f9168),
	('X', 0x1278ad), ('Y', 0x25dbca),
	('X', 0x7ce29d), ('Y', 0xab6986),
	('X', 0xa6b3f3), ('Y', 0xb8c326),
	('X', 0xd4b78e), ('Y', 0x7fd50),
	('X', 0x3399e1), ('Y', 0xef2d44),
	('X', 0x7c2f05), ('Y', 0x86a680),
	('X', 0xbae44e), ('Y', 0xddeaeb),
	('X', 0xe34722), ('Y', 0xe6a507),
	('X', 0x7f9fd5), ('Y', 0x834464),
]
symbols = {
	'X': '|..|..||',
	'Y': '|..|.||.',
	'Z': '|..|||..',
	'0': '|.',
	'1': '||',
}
state = 0
out = '0\n'*10
for preamble, data in samples:
	data_sym = bin(data | (1<<24))[3:][::-1]
	payload = data_sym + '100'
	parity = '1' if payload.count('1') % 2 else '0'
	payload = preamble + payload + parity
	print(payload)
	payload = ''.join(symbols[sym] for sym in payload)
	for ch in payload:
		if ch == '|':
			state = not state
		out += ('1' if state else '0') + '\n'
# print(out)
with open('spdif.txt','w') as fp:
	fp.write(out)