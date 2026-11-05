"""Google credentials for every script in this repo — no key path in code.

Credentials come from Application Default Credentials (ADC), i.e. the
GOOGLE_APPLICATION_CREDENTIALS environment variable, which is set once at the
Windows user level and therefore applies to every folder, terminal and session.

Usage:

    from google_auth import credentials
    creds = credentials(SHEETS_RO)          # or SHEETS_RW, DRIVE_RO

Nothing here hardcodes a file path. To point at a different service account,
change the environment variable, not this file:

    [Environment]::SetEnvironmentVariable(
        'GOOGLE_APPLICATION_CREDENTIALS', '<path to key>.json', 'User')
"""
import os

from google.auth import default
from google.auth.exceptions import DefaultCredentialsError

SHEETS_RW = ["https://www.googleapis.com/auth/spreadsheets"]
SHEETS_RO = ["https://www.googleapis.com/auth/spreadsheets.readonly"]
DRIVE_RO = ["https://www.googleapis.com/auth/drive.readonly"]

_HELP = """
No Google credentials found.

Application Default Credentials are not configured, so scripts cannot reach
Google Sheets. Set the environment variable once (PowerShell), then open a new
terminal:

    [Environment]::SetEnvironmentVariable(
        'GOOGLE_APPLICATION_CREDENTIALS',
        'C:\\Users\\user\\.secrets\\ew-sheets-sa.json',
        'User')

Check it with:

    python -c "import os; print(os.environ.get('GOOGLE_APPLICATION_CREDENTIALS'))"
""".strip()


def credentials(scopes=None):
    """Return ADC credentials for the given scopes (default: Sheets read/write)."""
    try:
        creds, _ = default(scopes=scopes or SHEETS_RW)
    except DefaultCredentialsError as exc:
        raise SystemExit(f"{_HELP}\n\nUnderlying error: {exc}") from exc
    return creds


def key_path():
    """Path ADC is using, for diagnostics only. None when ADC resolves another way."""
    return os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")


if __name__ == "__main__":
    print(f"GOOGLE_APPLICATION_CREDENTIALS = {key_path()}")
    creds = credentials(SHEETS_RO)
    email = getattr(creds, "service_account_email", "(not a service account)")
    print(f"resolved credentials OK -> {email}")
