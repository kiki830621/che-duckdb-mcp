# Privacy Policy for che-duckdb-mcp

## Data Collection

This MCP server **does not collect, store, or transmit** any personal data to external servers.

## Local Data Access

The server accesses only:

1. **DuckDB database files** - Only files explicitly specified by the user via the `db_connect` tool
2. **DuckDB documentation** - Downloaded from the official DuckDB website and cached locally in a temporary directory

## Network Access

The server makes network requests only to:

- `duckdb.org` - To download official DuckDB documentation (only when using `refresh_docs` or when documentation is not cached)

## Data Storage

- **Documentation cache**: Stored in the system's temporary directory (`/tmp/` or equivalent)
- **Query results**: Returned to the MCP client only, never stored persistently

## Third-Party Services

This server does not use any third-party analytics, tracking, or data collection services.

## Security

- Database connections are local only
- No remote database connections are supported
- SQL queries are executed only on user-specified local databases

## Contact

For privacy concerns or questions, please open an issue at:
https://github.com/kiki830621/che-duckdb-mcp/issues
