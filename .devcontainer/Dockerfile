# miseの公式Debianイメージ．git，curl，CA証明書とmiseを含み，
# PATHに/mise/shims，MISE_DATA_DIRに/miseが設定済み．
FROM jdxcode/mise:2026.9.12-debian

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
	openssh-client \
	procps \
	jq \
	libatomic1 \
	&& rm -rf /var/lib/apt/lists/*

# Quintが初回の実行時にダウンロードする評価器とApalacheを，先にQUINT_HOMEへ置く．
# 版は，package.jsonで固定したQuintに埋め込まれた版と一致させる(mise run checkが確かめる)．
ARG QUINT_EVALUATOR_VERSION=v0.6.0
ARG APALACHE_VERSION=0.56.1
ENV QUINT_HOME=/opt/quint
RUN evaluator_dir="$QUINT_HOME/rust-evaluator-$QUINT_EVALUATOR_VERSION" \
	&& apalache_dir="$QUINT_HOME/apalache-dist-$APALACHE_VERSION" \
	&& mkdir -p "$evaluator_dir" "$apalache_dir" \
	&& curl -fsSL "https://github.com/informalsystems/quint/releases/download/evaluator/$QUINT_EVALUATOR_VERSION/quint_evaluator-$(uname -m)-unknown-linux-gnu.tar.gz" \
	| tar -xz -C "$evaluator_dir" \
	&& curl -fsSL "https://github.com/apalache-mc/apalache/releases/download/v$APALACHE_VERSION/apalache.tgz" \
	| tar -xz -C "$apalache_dir"

# ツール(rtk，lefthookなど)はmise.tomlのとおりにイメージへ入れる．
# 版を固定したい場合は，先に`mise lock`でmise.lockを作り，
# COPYの対象に加えたうえで`mise install --locked`にする．
WORKDIR /tmp/mise-bootstrap
COPY mise.toml ./
RUN mise trust \
	&& mise ls --current \
	&& mise install --verbose

# rtkのhookを有効化する．
RUN mkdir -p /root/.claude \
	&& rtk init -g --hook-only

# 起動後は，リポジトリのmise.tomlをグローバル設定として読む．
# これにより，/workspacesの外のディレクトリでも同じツールを使える．
# グローバル設定のルートも/workspacesにして，タスクをリポジトリ直下で実行させる
# (未指定だとホームディレクトリで実行される)．
ENV MISE_GLOBAL_CONFIG_FILE=/workspaces/mise.toml \
	MISE_GLOBAL_CONFIG_ROOT=/workspaces \
	MISE_TRUSTED_CONFIG_PATHS=/workspaces

WORKDIR /workspaces
