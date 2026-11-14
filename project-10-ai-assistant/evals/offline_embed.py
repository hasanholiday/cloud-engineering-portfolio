"""A deterministic, free stand-in for the embedding model: hashed word counts.
It measures lexical retrieval only. It proves the pipeline and gives a baseline; the real model should beat it."""
import hashlib
import re

DIM = 512
STOP = set("the a an of to in on for and or is are be it my do i can how what when does at with that this you your we our".split())


def embed(text):
    v = [0.0] * DIM
    for w in re.findall(r"[a-z0-9]+", text.lower()):
        if w in STOP:
            continue
        v[int(hashlib.md5(w.encode()).hexdigest(), 16) % DIM] += 1.0
    return v
