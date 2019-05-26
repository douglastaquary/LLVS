# Low-Level Versioned Store (LLVS)

_Author: Drew McCormack (@drewmccormack)_

## Introduction to LLVS

Ever wish it was as easy to move your app's data around as it is to push and pull your source code with a tool like Git? If so, read on.

### Why LLVS?

Application data is more decentralized than ever. It is rare to find it concentrated on a single device. Typically, a single user will have a multitude of devices, from phones to laptops and watches, and each device may have several independent processes running (eg today extension, sharing extension), each working with a copy of the data. How can you share all of this data, giving the user a consistent picture, without writing thousands of lines of custom code to handle each scenario?

Software developers faced a similar situation in the world of source control. They were faced with this question: How can multiple individuals all work together on the same source files across multiple computers? We all know how that played out. Advances in Source Control Management (SCM) led to systems like Git and GitHub.

These tools successfully solved the problem of decentralized collaboration, and it is odd that the same approach has not been applied to app data before. That's where LLVS comes in. It provides a basic framework for storing and moving data through the decentralized world in which our apps live.

### What is LLVS?

LLVS is a new kind of beast, and is not easy to characterize in terms of existing technologies. A reasonable description would be that it is a _decentralized, versioned, key-value storage framework_.

It works a bit like a traditional key-value store, in which you can insert data values for given unique keys. But LLVS adds to this several extra dimensions, namely, that every time a value is stored, it gets assigned a version, and each version has an ancestry of other versions which you can trace back in time. Just as with Git, you can retrieve the values for any version at any time, determine the differences between two versions, and merge together versions.

All of this would be great on its own, but if it were isolated to a single store, it still would not be very useful in our decentralized world. So LLVS can _send_ and _receive_ versions from other stores, in the same way that you _push_ and _pull_ from other repositories with Git.

If this still has you wondering what LLVS is about, here are a few other characterizations which may help you grok it. LLVS is...

- A decentralized, versioned, key-value storage framework
- An abstractive layer for handling the ancestry of a decentralized data set
- A Directed, Acyclic Graph (DAG) history of the data in your app
- A simple means to "sync up" data sets across devices, and in the cloud
- An append-only distributed store, with full versioned history

### What is LLVS _Not_?

At this point, you are probably trying to apply labels to LLVS; trying to categorize it in terms of what you are already acquainted with. Try to keep an open mind lest you miss important, atypical aspects of the framework. To help you in this direction, here is a list of things that LLVS is _not_:

- An Object Relational Modeling (ORM) framework
- A database
- A serialization framework
- A framework for developing web services

### Where Does it Fit In?

LLVS is an abstraction. It handles the history of a dataset, without needing to know what the data actually represents, how it is stored on disk, or even how it moves between devices. 

LLVS includes some classes to get you started. You can set up a basic store using the existing storage classes (eg file based), and distribute your data using an existing cloud service (eg CloudKit), but you could also choose to add support for your own store (eg SQLite) or cloud service (eg Firebase). And you are free to use any data format you like, including serialized Swift Codable values, JSON, and end-to-end encrypted formats.

## Some Simple Examples

This section shows simple code for getting started, and provides a means to better understand the framework, and where it fits in to your toolkit.

### Creating a Store

Creating a versioned store on a single device is as simple as passing in a directory URL.

```swift
let groupDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mycompany.myapp")!
let rootDir = groupDir.appendingPathComponent("MyStore")
let store = Store(rootDirectoryURL: rootStoreDirectory)
```

This code uses the app group container, which is useful if you want to share data with app extensions. LLVS stores can be shared directly between multiple processes, such as the main app and a sharing extension.

### Storing Values

When you first create a store, you will probably want to add some initial data.

```swift
let stringData = "My first data".data(using: .utf8)!
let newValueId = Value.Identifier("ABCDEF")
let newValue = Value(identifier: valueId, version: nil, data: stringData)
let insert: Value.Change = .insert(newValue)
let firstVersion = try store.addVersion(basedOnPredecessor: nil, storing: [insert])
```

This code...

1. Creates some data from the string "My first data".
2. Makes a `Value.Identifier` for the new data with string "ABCDEF". (You will often use a UUID for this.)
3. Combines the identifier and data in a `Value`.  
4. The value is wrapped in a `Change` type, in this case indicating that the value is being inserted into the store for the first time.
5. The last line creates a new version in the store, and stores the insertion change. Because it is the first version, it has no "predecessor" versions.

At this point, a new version is returned. You could typically store this version somewhere (eg a variable, a file, user defaults), so that it can be used in fetching data. 

Storing subsequent values is very similar. The only difference is that you need to pass in the version upon which the changes are based. 

```swift
let secondData = "My second data".data(using: .utf8)!
let secondValue = Value(identifier: .init("CDEFGH"), version: nil, data: secondData)
let secondInsert: Value.Change = .insert(secondValue)
let secondVersion = try store.addVersion(basedOnPredecessor: firstVersion.identifier, storing: [secondInsert])
```

The main difference here is that a non-nil predecessor is passed in when adding the version. The predecessor is just the identifier of the first version we created above.

We have also used a shorter notation for the identifier, creating it inline with `.init`, rather than explicitly storing it in a variable.

### Fetching Data

Once we have data in the store, we can of course retrieve it again. With LLVS you need to indicate which version of the data you want, because the store includes a complete history of changes.

```swift
let value = try store.value(.init("CDEFGH"), prevailingAt: secondVersion.identifier)!
let fetchedString = String(data: value.data, encoding: .utf8)
```

Here we have fetched the second value we added above, and converted back into a string. We passed in the second version identifier; if we had passed in the first version, which was created before the value was added, `nil` would have been returned.

What about the first value we added above? That was added before the second version, so it continues to exist in future versions. (We say it "prevails".) So we can fetch it in exactly the same way. 

```swift
let value = try store.value(.init("ABCDEF"), prevailingAt: secondVersion.identifier)!
let fetchedString = String(data: value.data, encoding: .utf8)
```

Even though it was not directly added in the second version, it remains in existence in descendent versions until it is explicitly removed.

### Updating and Removing Values

Just as you can _insert_ new values, you can also _update_ existing values, and _remove_ them.

```swift
let updateData = "An update of my first data".data(using: .utf8)!
let updateValue = Value(identifier: .init("ABCDEF"), version: nil, data: updateData)
let update: Value.Change = .update(updateValue)
let removal: Value.Change = .remove(.init("CDEFGH"))
let thirdVersion = try store.addVersion(basedOnPredecessor: secondVersion.identifier, storing: [update, removal])
```

The third version is based on the second one. There are two changes: it updates the value for "ABCDEF" with new data, and removes the value "CDEFGH". 

If we now attempted to fetch the value with identiifier "CDEFGH" at the third version, we would get `nil`; however. the value would still exist if we fetched the second version.

### Branching

If the history of changes is _serial_ — one set of changes always based on the preceeding — it is easy to work with your data. It gets more complex when _concurrent_ changes are made. If two versions are added at about the same time, you can end up with divergence of your data, and this will likely need to be merged at a later time.

An example of this is when a user makes changes on two different devices, with no interceding sync. Later, when the data does get transferred, the versions branch off, rather than appearing in a continuous ancestral line. This can even happen if you are not using sync; for example, if you have a sharing extension, and it adds a version while your main app is also adding a version.

### Navigating History

The `Version` type forms the basis of the history tracking in LLVS. A version can have up to two _predecessor_  versions upon which it is based, and it can have zero or more _successors_.

If a version has no successors, it is a _head_. You can ask for the heads at any time.

```swift
var heads: Set<Version.Identifier>?
store.queryHistory { history in
    heads = history.headIdentifiers
}
```

Getting the current heads is useful to determine what you need to merge together.

Use the `queryHistory` function to get a history object that you can navigate. You can request the heads, but you can also retrieve any version you choose.

Getting the most recent head is also easy.

```swift
let version: Version? = store.mostRecentHead
````

The most recent head is a convenient version to use when starting up an extension, or syncing for the first time on a new device. In effect, you are saying "take me to the newest data".

### Merging

### Setting Up an Exchange

### Sending and Receiving

## Installing

## Learning More

Samples
In code documentation
Blog

## Advantages of LLVS
- Full history of changes. 
    - You can fork and merge as much as you like.
    - You can diff two versions to get what changed
    - Checkout old versions
    - Playback changes
    - Revert commits for undo purposes
- No lock in
- Easy to extend to any cloud storage
- Can support pure peer-to-peer
- Can work with fully encrypted data
- Can add support for any on-disk storage you like. Sqlite, CouchDB, flat file, etc.
- Systematic 3-way merging of data. Use the built in arbiter, or create your own. You have full conrol.
- Extremely robust, because append only
- Multithreading is no problem, unlike ORMs
- Multiprocess is no problem. Great for extensions. No need to even send/receive (unless you prefer that)
- No risk of data conflicts. You can keep using your version until you are ready to merge. If other versions are added, they don't invalidate your data.

## FAQ

- Is there a version for Android?
    - No, but would love one
- Is there LLVS in the cloud?
    - No, but that would be awesome.

## Important Objectives

### Simple
- Just a simple key-value store, with a versioned history like Git
- No assumptions about what the values are. Could be anything from JSON to encrypted data and JPEG images.

### Very robust
- A crash should not render a store unusable. At worst, the most recent changes may be lost.
- LLVS should be resilient to all but deliberate tampering and disk level corruption.
- Corrupted SQLite databases caused by an unlucky crash during saving should be a thing of the past.

### Append Only
- Files in LLVS are immutable. No file should ever be updated once created.
- Merging two stores is equivalent to just taking the union of all files and directories.

### Versioned
- Works with versioned history.
- Can check out any version. Each version is a complete snapshot of the store.
- Can branch off into concurrent branches.
- Can merge branches, using powerful three-way merging.
- Can implement advanced features like undo, without losing changes introduced by sync.

### Concurrent
- Read/write from multiple threads/processes concurrently without corruption or locking

### Global
- Should be straightforward to sync a store with a server or via file system.
- Should be possible to put a store in a shared file system like Dropbox and sync that way.

### Programming Language, Operating System Agnostic
- Can create a store using any language, on any device, and with any operating system
- Can even author stores by hand if you really want to

### FilterMaping
- Support for basic mapes
- FilterMapes are versioned along with the values