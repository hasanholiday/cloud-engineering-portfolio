import unittest
from app import health_payload


class HealthTest(unittest.TestCase):
    def test_health_ok(self):
        self.assertEqual(health_payload()["status"], "ok")


if __name__ == "__main__":
    unittest.main()
