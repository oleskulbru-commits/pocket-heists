class_name TestSuite
extends RefCounted

func suite_name() -> String:
	return "unnamed"


# The argument is the Assert helper. It cannot be named `assert` because that word is a GDScript keyword.
func run(_check: Assert) -> void:
	pass


class Assert:
	var failures: Array[String] = []

	func eq(actual: Variant, expected: Variant, label: String = "") -> void:
		if actual != expected:
			failures.append(_line(label, "expected %s but was %s" % [expected, actual]))

	func is_true(value: Variant, label: String = "") -> void:
		if value != true:
			failures.append(_line(label, "expected true but was %s" % value))

	func fail(message: String) -> void:
		failures.append(message)

	func _line(label: String, detail: String) -> String:
		if label.is_empty():
			return detail
		return "%s: %s" % [label, detail]
