# Adding MCP servers

```
claude mcp add --transport http datadog-mcp https://mcp.datadoghq.com/api/unstable/mcp-server/mcp
claude mcp add --transport http github https://api.githubcopilot.com/mcp -H "Authorization: Bearer $GITHUB_PAT"
claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse
claude mcp add dwb-local -- npx -y @modelcontextprotocol/server-postgres postgresql://postgres:postgres@localhost:5434/dogdatastaging
claude mcp add orgstore-local -- npx -y @modelcontextprotocol/server-postgres postgresql://postgres:postgres@localhost:5435/aaa_authn
claude mcp add kubernetes -- npx mcp-server-kubernetes
```

# Removing MCP servers

```
claude mcp remove [mcp name]
```
