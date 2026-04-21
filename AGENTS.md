# AGENTS.md

## Current task
- Goal: generate thesis-ready markdown artifacts from frozen packet-profile validation results.
- Hardware testing and old .rsp debugging are out of scope.

## Hard rules
- Local Codex only.
- Do not run new hardware tests.
- Do not edit RTL, scripts, or packet profiles.
- Do not change clock, baud rate, transport, or Ethernet.
- Use only frozen summary artifacts as inputs.

## Inputs
- artifacts/regression/profile_thesis_summary.md
- artifacts/regression/profile_thesis_summary.csv
- txt/profiles/uav_telemetry_profile.jsonl
- txt/profiles/control_command_profile.jsonl
- txt/profiles/video_microchunk_profile.jsonl

## Outputs
- thesis_board_validation_section.md
- thesis_board_validation_table.md
- thesis_packet_profile_method.md
- thesis_tamper_test_summary.md

## Report format
- files created
- one suggested paragraph
- one suggested table
- one next writing action