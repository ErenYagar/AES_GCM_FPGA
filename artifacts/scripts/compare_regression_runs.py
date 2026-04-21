import argparse
import json
from pathlib import Path


def load_jsonl(path: Path):
    records = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            records.append(json.loads(line))
    return records


def keyed(records):
    return {record["global_index"]: record for record in records}


def record_signature(record):
    return {
        "result": record.get("result"),
        "status": record.get("status"),
        "status_code": record.get("status_code"),
        "expected_tag": record.get("expected_tag"),
        "actual_tag": record.get("actual_tag"),
        "expected_data": record.get("expected_data"),
        "actual_data": record.get("actual_data"),
        "tx_frame_hash": record.get("tx_frame_hash"),
        "rx_frame_hash": record.get("rx_frame_hash"),
        "tuple": record.get("tuple"),
    }


def main():
    parser = argparse.ArgumentParser(description="Compare two regression JSONL logs and find earliest divergence.")
    parser.add_argument("run_a")
    parser.add_argument("run_b")
    parser.add_argument("--out-json", default=None)
    args = parser.parse_args()

    run_a = load_jsonl(Path(args.run_a))
    run_b = load_jsonl(Path(args.run_b))
    map_a = keyed(run_a)
    map_b = keyed(run_b)

    indices = sorted(set(map_a) | set(map_b))
    divergence = None
    for index in indices:
        rec_a = map_a.get(index)
        rec_b = map_b.get(index)
        if rec_a is None or rec_b is None:
            divergence = {
                "global_index": index,
                "reason": "missing_record",
                "run_a": rec_a,
                "run_b": rec_b,
            }
            break
        if record_signature(rec_a) != record_signature(rec_b):
            divergence = {
                "global_index": index,
                "reason": "field_mismatch",
                "tuple": rec_a.get("tuple") or rec_b.get("tuple"),
                "run_a": record_signature(rec_a),
                "run_b": record_signature(rec_b),
            }
            break

    payload = {
        "run_a": str(Path(args.run_a)),
        "run_b": str(Path(args.run_b)),
        "records_a": len(run_a),
        "records_b": len(run_b),
        "earliest_divergence": divergence,
    }

    print(json.dumps(payload, indent=2, sort_keys=True))
    if args.out_json:
        Path(args.out_json).write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")


if __name__ == "__main__":
    main()
