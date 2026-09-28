# bx-activitypub

Outbound [ActivityPub](https://www.w3.org/TR/activitypub/) federation for BoxLang apps. Let people on Mastodon and the rest of the fediverse follow your app's accounts, and send them your posts, edits and deletions.

Your app keeps its data; the module handles the protocol: WebFinger, actor documents, HTTP Signatures, the inbox, a delivery queue that survives restarts, and NodeInfo.

**Status: 0.2.0.** Author mode (an account publishing `Article`s) is complete and verified against Mastodon. Your app can also accept **public replies** to its posts from the fediverse, and their edits and deletions, by implementing an optional second contract. Likes, boosts and everything else inbound are acknowledged and ignored.

## Requirements

- BoxLang 1.17+
- MySQL 8.0.13+ (the module's tables use `UUID_TO_BIN` and expression defaults), through a BoxLang datasource (`bx-mysql`)
- A public HTTPS hostname. Other servers must be able to reach you, and your hostname becomes part of every account's identity.
- [boxlang-express](https://forgebox.io/view/boxlang-express) for the bundled routes adapter. The core module doesn't depend on it.

## Install

```bash
install-bx-module bx-activitypub
```

or with CommandBox: `box install bx-activitypub`. Then create the tables in your app's database from the module's `sql/schema.sql`:

```bash
mysql your_database < boxlang_modules/bx-activitypub/sql/schema.sql
```

(That path is for an install into your app's own `boxlang_modules/`, i.e. with `--local`.)

The module adds six `Ap*` tables and never reads or writes any of yours. Its classes are available as `bxModules.bxactivitypub.*`.

**Upgrading from 0.1.x:** run `sql/upgrade-0.2.0.sql` once.

## How it fits together

You implement one class, `IHostApp`, which answers four questions about your data. The module does everything else.

```
your app ── IHostApp ──> bx-activitypub ──> signed HTTP ──> Mastodon, etc.
   │                          │
   └── express adapter ───────┘  (mounts the routes on your BoxExpress app)
```

### The `IHostApp` contract

Types are `"Person"` and `"Group"` for accounts, and `"post"` for posts.

| Method | Returns |
|---|---|
| `baseUrl()` | Your canonical origin, e.g. `"https://example.com"`. Account and post ids are built from it. |
| `findActor( type, name )` | `{ id, name, displayName, summary, avatar, header, url }` or `null`. `id` is your UUID for the account (keypairs and followers are keyed by it); `name` is the handle, as in `@name@host`; `summary` is HTML; `avatar`, `header` (the profile banner; Mastodon crops it to about 3:1) and `url` (the profile page) are optional absolute URLs. |
| `getObject( "post", id )` | `{ author, title, summary, content, url, published }` or `null`. `author` is the Person's `name`; `content` is HTML; `url` is the post's page; `published` is a date. |
| `isPublic( type, id )` | Whether this account or post may be federated at all. Checked before every lookup, serving and delivery; `false` means the module behaves as if it doesn't exist. Return `false` for drafts, private content and inactive accounts. |

### Optional: `IRemoteReplies`

Implement these too (`implements="bxModules.bxactivitypub.contracts.IHostApp,bxModules.bxactivitypub.contracts.IRemoteReplies"`) and replies from the fediverse to your public posts reach your app. Without them, the module stays one-way.

| Method | |
|---|---|
| `acceptRemoteReply( postId, parentId, reply )` | A new reply to `postId`; `parentId` is your id of the reply it answers, or `""` for the post. Return your id for it, or `null` to refuse it. |
| `updateRemoteReply( hostId, reply )` | Its author edited it. |
| `deleteRemoteReply( hostId )` | Its author deleted it, or their account. |

`reply` is `{ objectUrl, url, author { actorUrl, name, handle, profileUrl, avatarUrl }, contentHtml, sensitive, summary, published, attachmentCount }`.

- **`contentHtml` is untrusted HTML from another server.** Sanitize it before you store or render it (for example with bx-esapi's `sanitizeHTML()` and a policy that allows only what you want to show). The module removes the leading mention of your account but does nothing else to it.
- Only **public** replies are passed on. Followers-only replies and direct messages are dropped, and so is anything whose author isn't the account that signed it.
- Replies to replies you accepted arrive with `parentId` set, so threads keep their shape.
- `sensitive` and `summary` are the author's content warning; `attachmentCount` is how many images or files were attached (they aren't passed on).
- Moderation is yours: store replies as pending, publish them straight away, or anything in between.

## Minimal example

A blog with one account, `@blog`, and one post. Put these three files in one folder, install the modules into it, and create the tables:

```bash
install-bx-module bx-activitypub,boxlang-express,bx-mysql --local
mysql -e "CREATE DATABASE mydb"
mysql mydb < boxlang_modules/bx-activitypub/sql/schema.sql
```

**MyHost.bx**

```java
class implements="bxModules.bxactivitypub.contracts.IHostApp" {

	string function baseUrl() {
		return getSystemSetting( "PUBLIC_BASE_URL", "https://example.com" );
	}

	function findActor( required string type, required string name ) {
		if ( type == "Person" && name == "blog" ) {
			return {
				id          : "7d5c1f2e-3a4b-4c5d-8e6f-000000000001",
				name        : "blog",
				displayName : "My Blog",
				summary     : "<p>New posts from my blog.</p>",
				avatar      : "",
				url         : baseUrl() & "/"
			};
		}
		return javacast( "null", "" );
	}

	function getObject( required string type, required string id ) {
		if ( type == "post" && id == "7d5c1f2e-3a4b-4c5d-8e6f-000000000101" ) {
			return {
				author    : "blog",
				title     : "Hello, fediverse",
				summary   : "My first federated post.",
				content   : "<p>Hello from BoxLang.</p>",
				url       : baseUrl() & "/posts/hello-fediverse",
				published : parseDateTime( "2026-10-01T12:00:00Z" )
			};
		}
		return javacast( "null", "" );
	}

	boolean function isPublic( required string type, required string id ) {
		return true;
	}

}
```

**app.bxs**

```java
app  = boxExpress()
host = new MyHost()
ap   = new bxModules.bxactivitypub.models.ActivityPub( host = host, settings = { datasource : "mydb" } )

// Routes (WebFinger, actors, inboxes, posts, NodeInfo) and the delivery worker.
new bxModules.bxactivitypub.adapters.express().mount( app, ap )

// Your own pages. Mount them after the adapter: it answers ActivityPub requests and
// passes everything else through.
app.get( "/", ( req, res ) => res.send( "My Blog" ) )

// Send new posts, edits and deletions every two minutes.
app.schedule( 2 * 60 * 1000, () => {
	ap.syncPost( "7d5c1f2e-3a4b-4c5d-8e6f-000000000101" )
	ap.syncActor( "Person", "blog" )
}, { name : "activitypub-sync" } )

app.listen( 3000 )
```

**boxlang.json**

```json
{
	"datasources": {
		"mydb": {
			"driver": "mysql",
			"host": "127.0.0.1",
			"port": "3306",
			"database": "mydb",
			"username": "root"
		}
	},
	"logging": {
		"loggers": {
			"activitypub": { "level": "DEBUG", "appender": "file", "encoder": "text", "additive": false }
		}
	}
}
```

Run it behind your HTTPS hostname:

```bash
PUBLIC_BASE_URL=https://your.host boxlang --bx-config ./boxlang.json app.bxs
```

Then search Mastodon for `@blog@your.host`, follow it, and the post arrives within two minutes. Check it without Mastodon:

```bash
curl "https://your.host/.well-known/webfinger?resource=acct:blog@your.host"
curl -H "Accept: application/activity+json" https://your.host/u/blog
```

## Publishing

Call `syncPost( id )` for any post that might have changed, as often as you like. It compares the post with what was last sent and does whatever is needed:

| Post is… | Sends |
|---|---|
| public and never sent | `Create` |
| public, sent, and its title, summary, content or url changed | `Update` |
| sent before, and now not public or gone (`getObject` returns `null`) | `Delete`; its id then answers `410 Gone` |
| anything else | nothing |

`syncActor( type, name )` does the same for the account's profile (`Update{Person}`): name, bio, avatar, header or profile URL. `federatedPostIds()` lists every post currently on the fediverse, so a sweep can revisit posts that have since been unpublished or deleted. `publishPost( id )` sends a post's first `Create` explicitly.

A typical app runs a scheduled sweep: `syncPost` for its recent posts plus `federatedPostIds()`, then `syncActor`. Choose a cutoff for "recent". Mastodon files a post under its `published` date, so an old post federated today lands deep in followers' timelines, and backfilling your whole archive sends every new follower a flood.

**Some things are permanent.** Choose your hostname and handles before you federate for real: changing either orphans every follower. A post's id belongs forever to the account that first published it. A deleted post's id stays deleted: Mastodon won't accept it again, even if you republish the post.

## Routes

The express adapter mounts these. Account and post routes answer ActivityPub requests (`Accept: application/activity+json`) and redirect browsers to the `url` from your host, or pass them through.

| Method | Path | |
|---|---|---|
| GET | `/.well-known/webfinger` | `acct:name@host` or an account URL |
| GET | `/.well-known/nodeinfo`, `/nodeinfo/2.1` | NodeInfo |
| GET | `/actor` | Instance account; signs outgoing requests |
| GET | `/u/{name}`, `/c/{name}` | Person and Group accounts |
| POST | `/u/{name}/inbox`, `/c/{name}/inbox`, `/inbox` | Follow and Undo{Follow}; with `IRemoteReplies`, replies (Create/Update/Delete of a Note) |
| GET | `/u/{name}/outbox`, `/c/{name}/outbox` | Empty collection |
| GET | `/u/{name}/followers`, `/c/{name}/followers` | Follower count only |
| GET | `/post/{id}` | Posts |
| GET | `/activities/{type}/{uuid}` | Every activity that was sent |

`mount( app, ap, options )` options: `maxInboxBytes` (default 262144), `deliveryIntervalMs` (default 5000; `0` to schedule the delivery worker yourself with `ap.processDeliveries()`).

## Settings

Passed to `new ActivityPub( host, settings )`:

| Setting | Default | |
|---|---|---|
| `datasource` | (required) | Where the `Ap*` tables live |
| `maxAgeSeconds` | `3600` | Oldest signed `Date` accepted on incoming requests |
| `maxFutureSeconds` | `300` | Furthest-ahead signed `Date` accepted |
| `httpTimeoutSeconds` | `10` | Outgoing connect and request timeout |
| `userAgent` | `bx-activitypub/{version} (+{baseUrl})` | Outgoing User-Agent |
| `softwareName`, `softwareVersion` | `bx-activitypub`, module version | Reported in NodeInfo |

## Security

- Every incoming activity the module acts on must carry a valid HTTP Signature from the activity's own actor, with a matching `Digest` and a recent `Date`. Anything it doesn't act on is acknowledged without fetching anything. The `Host` is checked against your configured base URL, so a tunnel or proxy that rewrites it can't break verification.
- Outgoing requests go only to HTTPS URLs on public addresses, and a remote account's inboxes must be on its own host, so a hostile account can't aim your server at internal or third-party URLs.
- Private keys are stored in the `ApActorKey` table. Encrypt the database at rest if it's shared with anything else.

## Delivery

Deliveries are queued in `ApDelivery`, so a restart loses nothing, and several app instances can run the worker at once. Failed deliveries retry after 1m, 5m, 30m, 2h and 12h, then give up. Each run sends to up to 10 inboxes in parallel, so a slow or dead server can't hold up the rest. Each inbox receives its activities in the order they were created. A `410 Gone` removes the followers behind that inbox.

## Logging

Everything goes to the `activitypub` logger. At `DEBUG`, as in the example, it records every inbound and outbound request with headers and body, which is how you debug a signature mismatch. Leave it at the default level in production.

## Development

```bash
box install
mysql -e "CREATE DATABASE bxactivitypub_test"
box run-script test
```

Tests use the `bxactivitypub_test` database (see `tests/boxlang.json`). `examples/dev-host/` is a small app for trying the module over a tunnel.

## License

MIT
