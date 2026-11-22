extends SceneTree

const SuiteScript := preload("res://tests/test_suite.gd")


func _init() -> void:
	quit(_run())


func _run() -> int:
	var paths := _collect("res://tests")
	paths.sort()
	if paths.is_empty():
		push_error("no test suites found")
		return 1
	var failed := false
	for path in paths:
		if not _run_suite(path):
			failed = true
	return 1 if failed else 0


func _run_suite(path: String) -> bool:
	var resource := load(path)
	if resource == null or not (resource is Script) or not resource.can_instantiate():
		push_error("FAIL %s: failed to load" % path)
		return false
	var suite: Object = resource.new()
	if suite == null:
		push_error("FAIL %s: failed to instantiate" % path)
		return false
	var suite_name := path
	if suite.has_method("suite_name"):
		suite_name = str(suite.suite_name())
	var check := SuiteScript.Assert.new()
	if suite.has_method("run"):
		suite.run(check)
	else:
		check.fail("missing run()")
	if check.failures.is_empty():
		print("PASS %s" % suite_name)
		return true
	for failure in check.failures:
		push_error("FAIL %s: %s" % [suite_name, failure])
	return false


func _collect(root: String) -> PackedStringArray:
	var found := PackedStringArray()
	_scan(root, found)
	return found


func _scan(root: String, found: PackedStringArray) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		push_error("FAIL %s: failed to open" % root)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var path := root.path_join(entry)
			if dir.current_is_dir():
				_scan(path, found)
			elif entry.ends_with("_test.gd"):
				found.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
