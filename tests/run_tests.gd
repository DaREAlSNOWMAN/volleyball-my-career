extends SceneTree

const CourtGeometryClass = preload("res://scripts/systems/court_geometry.gd")
const ContactResolverClass = preload("res://scripts/systems/contact_resolver.gd")
const PlayerAttributesClass = preload("res://resources/player_attributes.gd")
const TestGeometryClass = preload("res://tests/test_geometry.gd")
const TestContactClass = preload("res://tests/test_contact.gd")
const TestTrainingResetClass = preload("res://tests/test_training_reset.gd")
const TestPlaytestHarnessClass = preload("res://tests/test_playtest_harness.gd")

func _init():
	print("==================================================")
	print("       VOLLEYBALL MYCAREER - AUTOMATED TESTS      ")
	print("==================================================")
	var all_passed = true

	print("\n[SUITE 1/4] Court Geometry & In-Bounds Detection")
	var geom_passed = TestGeometryClass.run_all()
	all_passed = all_passed and geom_passed

	print("\n[SUITE 2/4] Assisted Spike Contact Mechanics & Net Clearance")
	var contact_passed = TestContactClass.run_all()
	all_passed = all_passed and contact_passed

	print("\n[SUITE 3/4] Training Loop Repeatability & Resets (10 reps)")
	var reset_passed = TestTrainingResetClass.run_all()
	all_passed = all_passed and reset_passed

	print("\n[SUITE 4/4] Scene-Level Playtest Harness (Scenarios A through J & 100 Cycles)")
	var harness_passed = TestPlaytestHarnessClass.run_all()
	all_passed = all_passed and harness_passed

	print("\n==================================================")
	if all_passed:
		print("       SUCCESS: ALL TEST SUITES PASSED!           ")
		print("==================================================")
		quit(0)
	else:
		printerr("       FAILURE: ONE OR MORE SUITES FAILED!        ")
		print("==================================================")
		quit(1)
