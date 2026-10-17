# DeepSeek Harness Integration

DeepSeek Harness (`dsh`) is a plugin-based agent harness that can connect to Houdry's GPU fabric as an alternative to Houdry Agent. This document explains how to configure `dsh` to use your Houdry fabric as its model backend.

## Overview

```text
DeepSeek Harness (Node.js Web UI)
        ↓
Custom model provider: Houdry fabric
        ↓
https://<fabric-host>:8080/v1/chat/completions
        ↓
Houdry router (model=auto) + scheduler
        ↓
GPU worker nodes → Model runtime (Ollama/vLLM/llama.cpp)
```

DeepSeek Harness acts as the agent UI and execution environment. Houdry provides the model inference backend through its OpenAI-compatible API.

## Prerequisites

- **Node.js** ≥ 22
- **pnpm** (install via `npm install -g pnpm`)
- **Houdry fabric** running (`houdry serve`) with at least one model available:
  - Either a GPU worker node registered (`houdry gpu register`)
  - Or Ollama running locally on the control plane host
- Network access between the machine running `dsh` and the Houdry fabric control plane

## Quick Start

Two integration methods are available:

### Method A: Native Plugin with WiFi Discovery (Recommended)

Uses the same automatic WiFi discovery protocol as Houdry Agent and GPU workers. Zero manual configuration when on the same network.

**1. Start Houdry fabric**

```bash
houdry serve --listen 0.0.0.0:8080
```

Register GPU workers:

```bash
houdry gpu detect
houdry gpu register
```

**2. Install Houdry plugin**

From the Houdry-harness repository:

```bash
cd Houdry-harness
pnpm install
pnpm run build
```

The `llm-houdry` plugin is included in the repository at `packages/llm/llm-houdry/`.

**3. Configure plugin**

Edit your DeepSeek Harness profile configuration (or add via Web UI):

```yaml
plugins:
  llm-houdry:
    enableDiscovery: true  # Automatic WiFi discovery
    discoveryTimeout: 3000
```

Leave `baseURL` empty. The plugin finds the control plane automatically using mDNS and UDP broadcast (same protocol as Houdry Agent).

**4. Run DeepSeek Harness**

```bash
export NODE_EXTRA_CA_CERTS="$HOME/.houdry/server/pki/root_ca.crt"
pnpm dsh web
```

The plugin will discover the fabric on WiFi and connect automatically.

**5. Start a chat**

Select `model=auto` (recommended) or a specific model. The fabric routes intelligently to available GPU workers.

---

### Method B: Manual Configuration via Custom Provider

If WiFi discovery is not available (different networks, firewall restrictions, etc.), use the manual OpenAI-compatible provider setup.

**1. Start Houdry fabric**

Same as Method A.

**2. Run DeepSeek Harness**

```bash
npx @deepseek-ai/dsh web
```

The Web UI opens at `http://127.0.0.1:3080` by default.

**3. Configure Houdry as Model Provider**

In the DeepSeek Harness Web UI:

1. Click **Settings** (gear icon)
2. Navigate to **Models** tab
3. Click **Add model provider**
4. Select **Custom model API**
5. Fill in the connection details:

   - **Name**: `Houdry Fabric`
   - **Protocol**: `OpenAI Chat Completions`
   - **Base URL**: `https://<fabric-host>:8080/v1`
     - Use `https://127.0.0.1:8080/v1` if `dsh` runs on the same machine as the fabric
     - Use `https://<fabric-ip>:8080/v1` if on a different machine on the same network
   - **API Key**: Leave empty if your fabric has no `--token`; otherwise enter the token value
   - **Custom CA Certificate**: Copy the contents of `~/.houdry/server/pki/root_ca.crt`

6. Click **Fetch available models**
   - `dsh` will query `GET /v1/models` and populate the model list
   - You should see `auto` plus any models from your GPU workers or local Ollama

7. Select models to enable for this provider
8. Click **Save**

The configuration is stored in `$DSH_HOME/profiles/web/cordis.patch.yml` (default: `~/.dsh/profiles/web/cordis.patch.yml`) and hot-reloads automatically.

**4. Trust Houdry's TLS Certificate**

DeepSeek Harness makes HTTPS requests to the fabric. Since Houdry uses a self-signed CA, you need to trust it.

**Option A: Environment variable (recommended for development)**

```bash
export NODE_EXTRA_CA_CERTS="$HOME/.houdry/server/pki/root_ca.crt"
npx @deepseek-ai/dsh web
```

**Option B: Paste into UI**

When adding the custom model provider in Step 3, paste the full CA certificate (including `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----`) into the **Custom CA Certificate** field.

**Option C: System trust store (permanent)**

On Linux/macOS:

```bash
sudo cp ~/.houdry/server/pki/root_ca.crt /usr/local/share/ca-certificates/houdry-root-ca.crt
sudo update-ca-certificates
```

On Windows (PowerShell as Administrator):

```powershell
Import-Certificate -FilePath "$HOME\.houdry\server\pki\root_ca.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

**5. Start a Chat

1. Create a new chat session
2. Select model `auto` (recommended) or a specific model from your fabric
3. Send a message

The inference runs through the Houdry fabric router, which:
- Analyzes the prompt (modality, complexity, capabilities)
- Selects an appropriate model and GPU node
- Creates an inference job
- Returns the result to DeepSeek Harness

## Configuration Details

### Model Selection

- **`auto`** (recommended): Houdry's Phase 5 router analyzes the prompt and selects the best available model and node
- **Explicit model** (e.g., `tinyllama:latest`, `qwen2.5-coder:1.5b`): Pins inference to that model; Houdry still picks the node via scheduler

### Tools and Function Calling

DeepSeek Harness can send tool definitions to models that support function calling. The fabric forwards these through to the model runtime (Ollama) and returns structured `tool_calls` in OpenAI format.

Use a tool-capable model like `qwen2.5-coder:1.5b` for reliable tool use. Small non-tuned models may emit tool JSON as text instead of structured calls.

### Streaming

`dsh` supports streaming responses. The fabric currently buffers the full response and streams it post-completion (SSE). True token-by-token streaming is a future enhancement.

## Verification

Test the connection with `curl` before configuring `dsh`:

```bash
curl --cacert "$HOME/.houdry/server/pki/root_ca.crt" \
  https://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "messages": [
      {"role": "user", "content": "Say hello from Houdry"}
    ]
  }'
```

Expected response:

```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1729000000,
  "model": "tinyllama:latest",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "Hello from Houdry! ..."
    },
    "finish_reason": "stop"
  }],
  "usage": {
    "prompt_tokens": 11,
    "completion_tokens": 7,
    "total_tokens": 18
  }
}
```

## Troubleshooting

### TLS handshake errors

**Symptom**: `dsh` cannot connect; logs show certificate errors

**Solution**: Ensure the Houdry Root CA is trusted (see Step 4 above). Verify the CA certificate path:

```bash
ls -l ~/.houdry/server/pki/root_ca.crt
```

### No models available

**Symptom**: "Fetch available models" returns empty or only `auto`

**Solution**: 
- Verify at least one model is available: `houdry model list --server https://127.0.0.1:8080`
- If using a GPU worker, ensure it's READY: `houdry node list --server https://127.0.0.1:8080`
- If using local Ollama, verify it's running: `curl http://127.0.0.1:11434/api/tags`

### Inference timeout

**Symptom**: Requests hang or timeout after 10 minutes

**Solution**: 
- Increase the fabric's wait budget: `houdry serve --openai-wait 15m`
- Check node status: a BUSY node won't accept new jobs until its current job completes
- For large models or slow GPUs, consider pre-loading models on workers

### Model not found

**Symptom**: `dsh` shows the model in the list, but inference fails with "model_unavailable"

**Solution**: The model may be in the catalog but not actually pulled on any worker. Pull it:

```bash
# On the GPU worker machine
ollama pull tinyllama
```

Then verify:

```bash
houdry model list --server https://127.0.0.1:8080
```

### Connection refused

**Symptom**: `dsh` cannot reach `https://<fabric-host>:8080`

**Solution**:
- Verify the fabric is running: `curl --cacert ~/.houdry/server/pki/root_ca.crt https://127.0.0.1:8080/healthz`
- Check firewall rules (Windows Firewall, iptables, etc.)
- Ensure you're using `https://`, not `http://`
- If on different machines, verify network connectivity: `ping <fabric-host>`

## Architecture Notes

### Why this integration works

Houdry's fabric exposes `POST /v1/chat/completions` and `GET /v1/models` — the same endpoints OpenAI SDKs expect. DeepSeek Harness's custom model provider treats Houdry as an OpenAI-compatible backend.

Requests flow:
1. `dsh` sends OpenAI-format request to `/v1/chat/completions`
2. Fabric routes the prompt (if `model=auto`) or validates the explicit model
3. Fabric creates an inference job and assigns it to a node
4. Node agent claims the job, runs it through Ollama/vLLM/llama.cpp
5. Node reports the result back to the fabric
6. Fabric returns OpenAI-format response to `dsh`

### Security

- **mTLS**: Node agents (GPU workers) use client certificates for authentication. The `/v1` API does not require client certs, only server TLS.
- **Token auth**: Pass `--token` to `houdry serve` to require `Authorization: Bearer <token>` or `X-Houdry-Token` header. Configure this in `dsh`'s API Key field.
- **Network isolation**: Keep the fabric on a private network. Do not expose `0.0.0.0:8080` to the internet without additional authentication/authorization.

### Differences from Houdry Agent

| Feature | Houdry Agent | DeepSeek Harness (Native Plugin) | DeepSeek Harness (Manual Provider) |
|---------|--------------|----------------------------------|-------------------------------------|
| Language | Electron (JavaScript) | Node.js + Cordis | Node.js + Cordis |
| UI | Desktop app (fork of Hermes) | Web UI (browser) | Web UI (browser) |
| Architecture | Monolithic agent | Plugin-based harness | Plugin-based harness |
| Discovery | WiFi mDNS + UDP (automatic) | WiFi mDNS + UDP (automatic) | Manual URL configuration |
| CA Trust | Auto-loaded | Auto-loaded from ~/.houdry | Manual paste into UI |
| Setup | Zero-config (same WiFi) | Zero-config (same WiFi) | Multi-step manual |
| Platform | Windows, macOS, Linux | Cross-platform | Cross-platform |
| Agent framework | Built-in | Extensible via plugins | Extensible via plugins |

All three use the same Houdry fabric `/v1` API. Choose based on your workflow:
- **Houdry Agent**: Recommended for desktop users who want a native app experience
- **DeepSeek Harness (Native Plugin)**: For developers on the same WiFi who want automatic discovery like Houdry Agent
- **DeepSeek Harness (Manual Provider)**: When WiFi discovery is not available (firewall, different networks, etc.)

## Advanced Configuration

### Multiple fabrics

You can configure multiple Houdry fabrics as separate providers in `dsh`:

1. Add first fabric: `Houdry Fabric (Office)`
2. Add second fabric: `Houdry Fabric (Lab)`
3. Select which provider's models to use per chat session

### Custom model mappings

DeepSeek Harness uses the model IDs returned by `GET /v1/models`. These match your Ollama model tags (`tinyllama:latest`, etc.). To use a custom display name, create a model alias in your `dsh` configuration.

### Batch inference

The fabric's job queue naturally supports batch requests. Submit multiple inference jobs via the native `/v1/jobs` API (not through `dsh`'s `/v1/chat/completions` path) for bulk processing.

## Related Documentation

- [OpenAI-compatible API](OpenAI-compatible-API.md) — full `/v1` API specification
- [Phase 5: Routing](Phase-5-routing.md) — how `model=auto` works
- [GPU Discovery](GPU-discovery.md) — adding GPU workers to the fabric
- [Security: PKI](security/PKI.md) — TLS certificate management
- [Houdry Agent](https://github.com/houdry-genomex/houdry-agent) — alternative Desktop client

## Feedback

DeepSeek Harness is in developer preview (v0.2.1-alpha.3 as of writing). Both `dsh` and Houdry are evolving rapidly. If you encounter integration issues:

1. Check `dsh` logs: `$DSH_HOME/profiles/web/logs/` (default: `~/.dsh/profiles/web/logs/`)
2. Check fabric logs: `houdry serve` output
3. Verify the request/response with `curl` to isolate whether the issue is in `dsh` or the fabric
4. Consult `dsh` documentation: https://deepseek-harness.github.io/deepseek-harness/
5. Report fabric-specific issues to Houdry repository; report `dsh` issues to DeepSeek Harness repository

## Summary

DeepSeek Harness integrates with Houdry fabric through the standard OpenAI-compatible `/v1` API. Configuration is straightforward:

1. Run `houdry serve` with models available
2. Run `dsh web`
3. Add Houdry as a custom OpenAI-compatible provider
4. Trust the Houdry Root CA certificate
5. Chat with `model=auto` for automatic routing

The integration is production-ready for developer preview usage. Both systems continue to iterate rapidly — consult this document for updates after upgrading either component.
