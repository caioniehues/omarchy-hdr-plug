#!/usr/bin/env bats

load helpers

@test "state persists under the caioniehues.hdr XDG state dir" {
  hdr_set on
  [ -f "$(state_file)" ]
}
