import unittest

from contract import request_parser


class RequestParserTests(unittest.TestCase):
    def test_accepts_fish_json_payload(self):
        payload = {"text": "Hola.", "reference_id": "vtuber", "format": "wav"}
        self.assertEqual(request_parser(payload), payload)

    def test_accepts_vast_input_wrapper(self):
        self.assertEqual(request_parser({"input": {"text": "Hola."}}), {"text": "Hola."})

    def test_rejects_missing_or_blank_text(self):
        for payload in ({}, {"text": "  "}, {"input": []}):
            with self.subTest(payload=payload):
                with self.assertRaises(ValueError):
                    request_parser(payload)
