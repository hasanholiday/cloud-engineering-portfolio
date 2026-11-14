"""Stage 4: an agent is a model that can use tools. The keys you hand it are the security design.

- The model only sees tools in the allowlist.
- Low-risk tools run. Risky tools (anything that sends or changes things outside) never run on their own:
  they are recorded as 'pending human approval'.
- The loop has a hard step limit so a confused model cannot run forever or burn money.
"""
import json


def make_tools(search_handbook, open_ticket):
    return {
        "search_handbook": {
            "fn": search_handbook, "risky": False,
            "spec": {"name": "search_handbook", "description": "Find handbook passages for a question.",
                     "inputSchema": {"json": {"type": "object", "properties": {"question": {"type": "string"}}, "required": ["question"]}}},
        },
        "open_ticket": {
            "fn": open_ticket, "risky": False,
            "spec": {"name": "open_ticket", "description": "Open an HR ticket when the handbook has no answer.",
                     "inputSchema": {"json": {"type": "object", "properties": {"summary": {"type": "string"}}, "required": ["summary"]}}},
        },
        "send_email": {  # deliberately risky: never auto-executed
            "fn": None, "risky": True,
            "spec": {"name": "send_email", "description": "Email someone. Needs human approval.",
                     "inputSchema": {"json": {"type": "object", "properties": {"to": {"type": "string"}, "body": {"type": "string"}}, "required": ["to", "body"]}}},
        },
    }


def run_agent(question, model_step, tools, allowed=("search_handbook", "open_ticket", "send_email"), max_steps=4):
    """model_step(messages, tool_specs) -> {'type':'text','text':..} or {'type':'tool_use','id','name','input'}."""
    specs = [tools[n]["spec"] for n in allowed if n in tools]
    messages = [{"role": "user", "content": question}]
    trace, pending = [], []
    for step in range(max_steps):
        out = model_step(messages, specs)
        if out["type"] == "text":
            return {"answer": out["text"], "trace": trace, "pending_approval": pending}
        name, args = out["name"], out.get("input", {})
        if name not in allowed or name not in tools:
            result = {"error": f"tool '{name}' is not allowed"}
        elif tools[name]["risky"]:
            pending.append({"tool": name, "input": args})
            result = {"status": "pending human approval; do not assume it was sent"}
        else:
            result = tools[name]["fn"](**args)
        trace.append({"step": step, "tool": name, "input": args})
        messages.append({"role": "assistant", "tool_use": out})
        messages.append({"role": "user", "tool_result": {"id": out.get("id"), "content": json.dumps(result)}})
    return {"answer": "Stopped: too many steps. A person should look at this.", "trace": trace, "pending_approval": pending}
