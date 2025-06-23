local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

ls.snippets = ls.snippets or {}

ls.add_snippets("javascript", {
	s("wb", {
		t("writeBlock("),
		i(1, '"Hello, World!"'),
		t(");"),
	}),

	s("wl", {
		t("writeln("),
		i(1, '"Log Message"'),
		t(");"),
	}),
	s("wc", {
		t("writeComment("),
		i(1, '"Hello, World!"'),
		t(");"),
	}),
	s("iff", {
		t("if ("),
		i(1, '"Hello, World!"'),
		t(") {"),
		i(2, '"add stuff"'),
		t("};"),
	}),
})
