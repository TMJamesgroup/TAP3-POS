import unittest
from simulator import CashDrawerSimulator

class SimulatorTests(unittest.TestCase):
    def setUp(self):
        self.s = CashDrawerSimulator()
        self.s.configure("bar-1", 25000, "manager", "Opening bank")

    def test_opening_and_logging(self):
        self.s.start_shift("bar-1", "bartender", {10000: 2, 5000: 1})
        self.assertTrue(self.s.open_drawer("bar-1", "bartender", "make change")["simulated"])
        with self.assertRaises(PermissionError):
            self.s.open_drawer("bar-1", "other", "make change")
        self.assertFalse(self.s.drawers["bar-1"].events[-1]["allowed"])

    def test_movement_and_blind_count(self):
        self.s.start_shift("bar-1", "bartender", {10000: 2, 5000: 1})
        self.s.movement("bar-1", "bartender", "cash_sale", 1000, "order")
        result = self.s.blind_count("bar-1", "manager", {10000: 2, 5000: 1, 1000: 1})
        self.assertEqual(result["variance_cents"], 0)

    def test_variance_blocks_shift(self):
        with self.assertRaises(ValueError):
            self.s.start_shift("bar-1", "bartender", {10000: 1})
        self.assertFalse(self.s.drawers["bar-1"].open_shift)

    def test_transfer_requires_two_matching_counts(self):
        self.s.start_shift("bar-1", "bartender", {10000: 2, 5000: 1})
        with self.assertRaises(ValueError):
            self.s.transfer_shift("bar-1", "bartender", "next", {10000: 2, 5000: 1}, {10000: 1})
        self.assertEqual(self.s.drawers["bar-1"].assigned_employee, "bartender")
        self.s.transfer_shift("bar-1", "bartender", "next", {10000: 2, 5000: 1}, {10000: 2, 5000: 1})
        self.assertEqual(self.s.drawers["bar-1"].assigned_employee, "next")

    def test_no_real_print(self):
        job = self.s.receipt(["Burger"], 1500)
        self.assertFalse(job["printed"])
        self.assertFalse(job["hardware_command_sent"])

if __name__ == "__main__":
    unittest.main()
