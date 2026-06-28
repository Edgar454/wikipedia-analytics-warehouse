import json

with open("key.json", "r") as f:
    key_contents = f.read()

flattened = json.dumps(json.loads(key_contents))  # re-serializes as a single line, valid JSON preserved
print(flattened)