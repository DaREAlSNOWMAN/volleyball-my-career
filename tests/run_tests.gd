extends SceneTree

const CourtGeometryClass = preload("res://scripts/systems/court_geometry.gd")
const ContactResolverClass = preload("res://scripts/systems/contact_resolver.gd")
const PlayerAttributesClass = preload("res://resources/player_attributes.gd")
const TestGeometryClass = preload("res://tests/test_geometry.gd")
const TestContactClass = preload("res://tests/test_contact.gd")
const TestTrainingResetClass = preload("res://tests/test_training_reset.gd")

func _init():
	print("==================================================")
	print("       VOLLEYBALL MYCAREER - AUTOMATED TESTS      ")
	print("==================================================")
	var all_passed = true

	print("\n[SUITE 1/3] Court Geometry & In-Bounds Detection")
	var geom_passed = TestGeometryClass.run_all()
	all_passed = all_passed and geom_passed

	print("\n[SUITE 2/3] Assisted Spike Contact Mechanics")
	var contact_passed = TestContactClass.run_all()
	all_passed = all_passed and contact_passed

	print("\n[SUITE 3/3] Training Loop Repeatability & Resets (10 reps)")
	var reset_passed = TestTrainingResetClass.run_all()
	all_passed = all_passed and reset_passed

	print("\n==================================================")
	if all_passed:
		print("       SUCCESS: ALL TEST SUITES PASSED!           ")
		print("==================================================")
		quit(0)
	else:
		printerr("       FAILURE: ONE OR MORE SUITES FAILED!        ")
		print("==================================================")
		quit(1)
