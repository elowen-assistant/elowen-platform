create table if not exists threads (
    id text primary key,
    title text not null,
    status text not null,
    current_summary_id text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists messages (
    id text primary key,
    thread_id text not null references threads(id) on delete cascade,
    role text not null,
    content text not null,
    status text not null default 'committed',
    payload_json jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists devices (
    id text primary key,
    name text not null,
    primary_flag boolean not null default false,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists jobs (
    id text primary key,
    short_id text not null unique,
    title text not null,
    thread_id text not null references threads(id) on delete cascade,
    status text not null,
    result text,
    failure_class text,
    repo_name text not null,
    device_id text references devices(id),
    branch_name text,
    base_branch text,
    parent_job_id text references jobs(id),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    completed_at timestamptz
);

create table if not exists job_events (
    id text primary key,
    job_id text not null references jobs(id) on delete cascade,
    event_type text not null,
    payload_json jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create table if not exists approvals (
    id text primary key,
    thread_id text not null references threads(id) on delete cascade,
    job_id text not null references jobs(id) on delete cascade,
    action_type text not null,
    status text not null,
    created_at timestamptz not null default now(),
    resolved_at timestamptz
);

create table if not exists thread_summaries (
    id text primary key,
    thread_id text not null references threads(id) on delete cascade,
    version integer not null,
    content text not null,
    created_at timestamptz not null default now(),
    unique (thread_id, version)
);

create table if not exists job_summaries (
    id text primary key,
    job_id text not null references jobs(id) on delete cascade,
    version integer not null,
    content text not null,
    created_at timestamptz not null default now(),
    unique (job_id, version)
);

create table if not exists note_references (
    note_id text not null,
    source_type text not null,
    source_id text not null,
    created_at timestamptz not null default now(),
    primary key (note_id, source_type, source_id)
);

create index if not exists idx_messages_thread_id on messages(thread_id);
create index if not exists idx_jobs_thread_id on jobs(thread_id);
create index if not exists idx_jobs_device_id on jobs(device_id);
create index if not exists idx_job_events_job_id on job_events(job_id);
create index if not exists idx_approvals_job_id on approvals(job_id);
