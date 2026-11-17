#!/usr/bin/env python3
"""Call one MCP tool on a stdio MCP server and print the text result.

Handy for checking what an agent would see, without an MCP client:

    MCP_SERVER="heron-ops --kubeconfig $HOME/.kube/config" \
        scripts/mcp-call.py get_pod '{"namespace":"demo","name":"broken-api-..."}'

MCP_SERVER is the server command line (default: "heron-ops --kubeconfig ~/.kube/config").
Starling Lite works too: MCP_SERVER="starling-lite --mode=readonly --kubeconfig ...".
Exits 1 if the tool returns an error result.
"""
import json
import os
import shlex
import subprocess
import sys


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    tool = sys.argv[1]
    args = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    server = os.environ.get(
        "MCP_SERVER", "heron-ops --kubeconfig " + os.path.expanduser("~/.kube/config")
    )
    msgs = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize",
         "params": {"protocolVersion": "2025-06-18", "capabilities": {},
                    "clientInfo": {"name": "mcp-call", "version": "0"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/call",
         "params": {"name": tool, "arguments": args}},
    ]
    proc = subprocess.run(
        shlex.split(server),
        input="".join(json.dumps(m) + "\n" for m in msgs),
        capture_output=True, text=True, timeout=120,
    )
    for line in proc.stdout.splitlines():
        try:
            resp = json.loads(line)
        except json.JSONDecodeError:
            continue
        if resp.get("id") != 2:
            continue
        if "error" in resp:
            print(json.dumps(resp["error"]), file=sys.stderr)
            return 1
        result = resp.get("result", {})
        for c in result.get("content", []):
            if c.get("type") == "text":
                print(c["text"])
        return 1 if result.get("isError") else 0
    print("no response for tools/call; server stderr:\n" + proc.stderr, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
