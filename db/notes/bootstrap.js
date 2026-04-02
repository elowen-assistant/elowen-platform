// Bootstrap draft for the elowen-notes ArangoDB database.
// Run this with arangosh against the target database once notes persistence is implemented.

const collections = [
  { name: "notes", edge: false },
  { name: "note_revisions", edge: false },
  { name: "note_types", edge: false },
  { name: "attachments", edge: false },
  { name: "note_links", edge: true },
  { name: "note_sources", edge: true }
];

for (const entry of collections) {
  if (!db._collection(entry.name)) {
    if (entry.edge) {
      db._createEdgeCollection(entry.name);
    } else {
      db._createDocumentCollection(entry.name);
    }
  }
}

const ensurePersistentIndex = (collection, fields, options = {}) => {
  db[collection].ensureIndex({
    type: "persistent",
    fields,
    ...options
  });
};

ensurePersistentIndex("notes", ["note_id"], { unique: true, name: "idx_notes_note_id" });
ensurePersistentIndex("notes", ["slug"], { unique: true, sparse: true, name: "idx_notes_slug" });
ensurePersistentIndex("note_revisions", ["revision_id"], { unique: true, name: "idx_revisions_revision_id" });
ensurePersistentIndex("note_revisions", ["note_id", "created_at"], { name: "idx_revisions_note_created" });
ensurePersistentIndex("note_revisions", ["note_id", "version"], { unique: true, name: "idx_revisions_note_version" });
ensurePersistentIndex("note_revisions", ["previous_revision_id"], { sparse: true, name: "idx_revisions_previous_revision" });
ensurePersistentIndex("note_types", ["type_key"], { unique: true, name: "idx_note_types_type_key" });
ensurePersistentIndex("attachments", ["attachment_id"], { unique: true, name: "idx_attachments_attachment_id" });

if (!db._view("notes_search")) {
  db._createView("notes_search", "arangosearch", {
    links: {
      notes: {
        includeAllFields: false,
        fields: {
          title: {},
          slug: {},
          tags: {},
          aliases: {}
        }
      },
      note_revisions: {
        includeAllFields: false,
        fields: {
          body_markdown: { analyzers: ["text_en"] },
          summary: { analyzers: ["text_en"] },
          frontmatter: {}
        }
      }
    }
  });
}
