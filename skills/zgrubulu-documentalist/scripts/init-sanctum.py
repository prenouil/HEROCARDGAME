#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# ///
"""
First Breath — Deterministic sanctum scaffolding.

This script runs BEFORE the conversational awakening. It creates the sanctum
folder structure, copies template files with values substituted, copies all
capability files and their supporting references into the sanctum, and
auto-generates CAPABILITIES.md from capability prompt frontmatter plus the
externally-delegated skills this agent always knows about.

After this script runs, the sanctum is fully self-contained — the agent does
not depend on the skill bundle location for normal operation.

Portability note: unlike a project-bound BMad agent, this agent's sanctum
lives INSIDE its own skill folder (`{skill-root}/memory/`), located via
`__file__`, not under a host project's `_bmad/`. `project-root` is optional
and used only as a best-effort source for a name/language seed (read from
`_bmad/config.yaml` if present) — the agent works identically without it.

This initializes the agent's runtime sanctum memory, not build-time config.
It never writes or authors any config file. Build-time customization is
owned by customize.toml, a separate surface this script never touches.

Usage:
    uv run init-sanctum.py [project-root]

    project-root: optional; a BMad project root to try seeding user_name /
                  communication_language from (falls back to cwd, then to
                  generic defaults refined during First Breath).
"""

import sys
from datetime import date
from pathlib import Path

# Files that stay in the skill bundle (only used during First Breath)
SKILL_ONLY_FILES = {"first-breath.md"}

TEMPLATE_FILES = [
    "INDEX-template.md",
    "PERSONA-template.md",
    "CREED-template.md",
    "BOND-template.md",
    "MEMORY-template.md",
    "PULSE-template.md",
]

# Whether the owner can teach this agent new capabilities
EVOLVABLE = True

# Skills this agent always knows how to delegate to — known at build time,
# not discoverable from local reference frontmatter, so listed explicitly.
EXTERNAL_CAPABILITIES = [
    {"code": "GD", "name": "Rédiger le GDD", "description": "Écrit ou met à jour le Game Design Document complet", "source": "External: `gds-gdd`"},
    {"code": "BR", "name": "Rédiger le Brief", "description": "Crée ou révise le Game Brief", "source": "External: `gds-create-game-brief`"},
    {"code": "NA", "name": "Rédiger la narration", "description": "Structure narrative, arcs, worldbuilding", "source": "External: `gds-create-narrative`"},
    {"code": "UX", "name": "Rédiger l'UX", "description": "Specs UX/UI/HUD", "source": "External: `gds-ux`"},
    {"code": "PR", "name": "Rédiger le PRD", "description": "PRD formel dérivé du GDD", "source": "External: `gds-prd`"},
]


def parse_yaml_config(config_path: Path) -> dict:
    """Simple YAML key-value parser. Handles top-level scalar values only."""
    config = {}
    if not config_path.exists():
        return config
    with open(config_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if ":" in line:
                key, _, value = line.partition(":")
                value = value.strip().strip("'\"")
                if value:
                    config[key.strip()] = value
    return config


def parse_frontmatter(file_path: Path) -> dict:
    """Extract simple YAML frontmatter from a markdown file (top-level scalars only)."""
    meta = {}
    text = file_path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return meta
    end = text.find("\n---", 3)
    if end == -1:
        return meta
    for line in text[3:end].strip().split("\n"):
        if ":" in line:
            key, _, value = line.partition(":")
            meta[key.strip()] = value.strip().strip("'\"")
    return meta


def copy_references(source_dir: Path, dest_dir: Path) -> list[str]:
    """Copy all reference files (except skill-only files) into the sanctum."""
    dest_dir.mkdir(parents=True, exist_ok=True)
    copied = []
    for source_file in sorted(source_dir.iterdir()):
        if source_file.name in SKILL_ONLY_FILES or not source_file.is_file():
            continue
        dest = dest_dir / source_file.name
        dest.write_bytes(source_file.read_bytes())
        copied.append(source_file.name)
    return copied


def discover_capabilities(references_dir: Path, sanctum_refs_path: str) -> list[dict]:
    """Scan references/ for internal capability prompt files with frontmatter."""
    capabilities = []
    for md_file in sorted(references_dir.glob("*.md")):
        if md_file.name in SKILL_ONLY_FILES:
            continue
        meta = parse_frontmatter(md_file)
        if meta.get("name") and meta.get("code"):
            capabilities.append({
                "name": meta["name"],
                "description": meta.get("description", ""),
                "code": meta["code"],
                "source": f"`{sanctum_refs_path}/{md_file.name}`",
            })
    return capabilities


def generate_capabilities_md(external: list[dict], internal: list[dict], evolvable: bool) -> str:
    """Generate CAPABILITIES.md: delegated skills first, then this agent's own territory."""
    lines = [
        "# Capabilities",
        "",
        "## Built-in",
        "",
        "| Code | Name | Description | Source |",
        "|------|------|-------------|--------|",
    ]
    for cap in external + internal:
        lines.append(f"| [{cap['code']}] | {cap['name']} | {cap['description']} | {cap['source']} |")

    if evolvable:
        lines.extend([
            "",
            "## Learned",
            "",
            "_Capabilities added by the owner over time. Prompts live in `capabilities/`._",
            "",
            "| Code | Name | Description | Source | Added |",
            "|------|------|-------------|--------|-------|",
            "",
            "## How to Add a Capability",
            "",
            'Tell me "I want you to be able to do X" and we\'ll create it together.',
            "I'll write the prompt, save it to `capabilities/`, and register it here.",
            "Next session, I'll know how.",
            "Load `references/capability-authoring.md` for the full creation framework.",
        ])

    lines.extend([
        "",
        "## Tools",
        "",
        "Prefer crafting your own tools over depending on external ones. A script you wrote "
        "and saved is more reliable than an external API. Use the file system creatively.",
        "",
        "### User-Provided Tools",
        "",
        "_MCP servers, APIs, or services the owner has made available. Document them here._",
    ])
    return "\n".join(lines) + "\n"


def substitute_vars(content: str, variables: dict) -> str:
    """Replace {var_name} placeholders with values from the variables dict."""
    for key, value in variables.items():
        content = content.replace(f"{{{key}}}", value)
    return content


def main() -> int:
    skill_path = Path(__file__).resolve().parent.parent
    sanctum_path = skill_path / "memory"
    assets_dir = skill_path / "assets"
    references_dir = skill_path / "references"

    sanctum_refs = sanctum_path / "references"
    sanctum_refs_path = "references"

    if sanctum_path.exists():
        print(f"Sanctum already exists at {sanctum_path}")
        print("This agent has already been born here. Skipping First Breath scaffolding.")
        return 0

    # Best-effort config seed: try an explicit project-root arg, then cwd, for a
    # BMad _bmad/config.yaml. Never required — generic defaults if absent.
    candidates = [Path(sys.argv[1]).resolve()] if len(sys.argv) > 1 else []
    candidates.append(Path.cwd())
    config: dict = {}
    for candidate in candidates:
        config = parse_yaml_config(candidate / "_bmad" / "config.yaml")
        if config:
            break

    variables = {
        "user_name": config.get("user_name", "l'ami"),
        "communication_language": config.get("communication_language", "french"),
        "birth_date": date.today().isoformat(),
    }

    sanctum_path.mkdir(parents=True, exist_ok=True)
    (sanctum_path / "capabilities").mkdir(exist_ok=True)
    (sanctum_path / "sessions").mkdir(exist_ok=True)
    print(f"Created sanctum at {sanctum_path}")

    copied_refs = copy_references(references_dir, sanctum_refs)
    print(f"  Copied {len(copied_refs)} reference files to sanctum/references/")
    for name in copied_refs:
        print(f"    - {name}")

    for template_name in TEMPLATE_FILES:
        template_path = assets_dir / template_name
        if not template_path.exists():
            print(f"  Warning: template {template_name} not found, skipping")
            continue
        output_name = template_name.replace("-template", "").upper()
        output_name = output_name[:-3] + ".md"
        content = substitute_vars(template_path.read_text(encoding="utf-8"), variables)
        (sanctum_path / output_name).write_text(content, encoding="utf-8")
        print(f"  Created {output_name}")

    internal_caps = discover_capabilities(references_dir, sanctum_refs_path)
    capabilities_content = generate_capabilities_md(EXTERNAL_CAPABILITIES, internal_caps, evolvable=EVOLVABLE)
    (sanctum_path / "CAPABILITIES.md").write_text(capabilities_content, encoding="utf-8")
    print(f"  Created CAPABILITIES.md ({len(EXTERNAL_CAPABILITIES)} delegated + {len(internal_caps)} built-in capabilities)")

    print()
    print("First Breath scaffolding complete.")
    print("The conversational awakening can now begin.")
    print(f"Sanctum: {sanctum_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
