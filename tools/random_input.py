"""Input script for a Mega Drive profiling run (runner --input-script): random play with START now and then,
screenshots at the given frames, EXIT at the end. Usage: random_input.py FRAMES SEED [SHOT_DIR]"""
import random, sys

frames, seed = int(sys.argv[1]), int(sys.argv[2])
shots = sys.argv[3] if len(sys.argv) > 3 else None
rng = random.Random(seed)
moves = ["RIGHT", "LEFT", "UP", "DOWN", "A", "B", "C"]
out, f = ["WAIT 30"], 30
next_shot = 600
while f < frames:
    if rng.random() < 0.08:
        out.append("PRESS START 6"); n = 40
    else:
        held = rng.sample(moves, rng.randint(1, 2))
        n = rng.randint(8, 90)
        out += [f"HOLD {b}" for b in held] + [f"WAIT {n}", "RELEASE"]
    if out[-1] != "RELEASE" and not out[-1].startswith("WAIT"):
        out.append(f"WAIT {n}")
    f += n
    if shots and f >= next_shot:
        out.append(f"SCREENSHOT {shots}/shot.png"); next_shot += 600
out.append("EXIT 0")
print("\n".join(out))
