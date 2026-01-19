# che-duckdb-mcp

整合版 DuckDB MCP Server，結合文檔查詢和資料庫操作功能。

## 功能

### 文檔工具 (8 個)

| 工具 | 功能 | 只讀 |
|------|------|------|
| `search_docs` | 搜索文檔 | ✓ |
| `list_sections` | 列出章節 | ✓ |
| `get_section` | 取得章節內容 | ✓ |
| `get_function_docs` | 查詢函數文檔 | ✓ |
| `list_functions` | 列出所有函數 | ✓ |
| `get_sql_syntax` | 查詢 SQL 語法 | ✓ |
| `refresh_docs` | 強制更新文檔 | ✗ |
| `get_doc_info` | 取得文檔資訊 | ✓ |

### 資料庫工具 (6 個)

| 工具 | 功能 | 只讀 |
|------|------|------|
| `db_connect` | 連接資料庫 | ✗ |
| `db_query` | 執行 SELECT 查詢 | ✓ |
| `db_execute` | 執行 DDL/DML | ✗ |
| `db_list_tables` | 列出表格和視圖 | ✓ |
| `db_describe` | 描述表格或查詢結構 | ✓ |
| `db_info` | 取得資料庫資訊 | ✓ |

## 安裝

### 編譯

```bash
cd che-duckdb-mcp
swift build -c release
```

### 部署

```bash
cp .build/release/CheDuckDBMCP ~/bin/
```

### 加入 Claude Code

```bash
claude mcp add --scope user che-duckdb-mcp -- ~/bin/CheDuckDBMCP
```

## 使用範例

### 文檔查詢

```
# 搜索文檔
search_docs: { "query": "read_csv" }

# 查詢函數文檔
get_function_docs: { "function_name": "json_extract" }

# 查詢 SQL 語法
get_sql_syntax: { "statement": "COPY" }
```

### 資料庫操作

```
# 連接記憶體資料庫
db_connect: {}

# 建立表格
db_execute: { "sql": "CREATE TABLE users (id INTEGER, name VARCHAR)" }

# 插入資料
db_execute: { "sql": "INSERT INTO users VALUES (1, 'Alice'), (2, 'Bob')" }

# 查詢資料（JSON 格式）
db_query: { "sql": "SELECT * FROM users", "format": "json" }

# 查詢資料（Markdown 格式，適合閱讀）
db_query: { "sql": "SELECT * FROM users", "format": "markdown" }

# 列出表格
db_list_tables: {}

# 描述表格結構
db_describe: { "table": "users" }
```

### 連接檔案資料庫

```
# 連接現有的 DuckDB 檔案
db_connect: { "path": "/path/to/database.duckdb" }

# 唯讀模式
db_connect: { "path": "/path/to/database.duckdb", "read_only": true }
```

## 輸出格式

### JSON 格式
```json
[
  {"id": 1, "name": "Alice"},
  {"id": 2, "name": "Bob"}
]
```

### Markdown 格式
```markdown
| id | name  |
|---:|-------|
| 1  | Alice |
| 2  | Bob   |
```

### CSV 格式
```csv
id,name
1,Alice
2,Bob
```

## 安全考量

1. **SQL 注入防護**：`db_query` 僅允許 SELECT、WITH、SHOW、DESCRIBE、EXPLAIN、PRAGMA 查詢
2. **資源限制**：預設限制返回 1000 行，防止記憶體溢出
3. **唯讀模式**：支援以唯讀模式開啟資料庫

## 系統需求

- macOS 13.0+
- 網路連線（用於下載文檔）

## 快取位置

- 文檔快取：`~/.cache/che-duckdb-mcp/duckdb-docs.md`
- 快取過期：24 小時

## 授權

MIT License
