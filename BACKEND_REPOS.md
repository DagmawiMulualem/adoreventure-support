# Where the Python API lives

| Repository | Role |
|------------|------|
| **`adoreventure-backend-clean`** | **Production** Flask API on Render. Source is updated from this monorepo’s `backend/` folder. |
| **`adoreventure-support`** | Monorepo: Firebase **`functions/`** (calls the API), static support site, **`backend/`** as the **only** maintained Python service code. |

## Rules

- **Do not** add a second `app.py` at the **repo root** — it was removed as a duplicate. All API code belongs under **`backend/`**.
- After changing anything in **`backend/`**, deploy Render by running from the project root:

  ```bash
  ./push_backend_render.sh
  ```

  That pushes the `backend/` subtree to **`adoreventure-backend-clean`** `main` (what Render builds).

- **`functions/index.js`** stays in **support** — it is the Firebase proxy and must **not** go to the backend repo.

## Render

- **Python web service** → GitHub **`adoreventure-backend-clean`** (Dockerfile + `app.py` at repo root after subtree push).
- **`render.yaml`** in **support** is only for the **static** `adoreventure-support` site (`support.html`), not the API.
