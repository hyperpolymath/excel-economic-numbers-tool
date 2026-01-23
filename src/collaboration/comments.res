// SPDX-License-Identifier: PMPL-1.0-or-later
/**
 * Comments and Annotations System - v8.0
 *
 * Thread-based commenting with mentions, reactions, and attachments
 */

type commentId = string
type userId = string
type threadId = string

type mentionType =
  | User(userId)
  | Team(string)
  | Everyone

type reactionType =
  | ThumbsUp
  | ThumbsDown
  | Heart
  | Celebrate
  | Confused

type attachmentType =
  | Image({url: string, width: int, height: int})
  | File({url: string, filename: string, size: int})
  | Link({url: string, title: string})

type comment = {
  id: commentId,
  threadId: threadId,
  author: userId,
  authorName: string,
  content: string,
  mentions: array<mentionType>,
  attachments: array<attachmentType>,
  reactions: array<(userId, reactionType)>,
  createdAt: Js.Date.t,
  updatedAt: option<Js.Date.t>,
  isEdited: bool,
  isResolved: bool,
  parentId: option<commentId>,
}

type commentThread = {
  id: threadId,
  documentId: string,
  anchorType: string, // "cell", "chart", "range", "document"
  anchorRef: string, // cell reference, chart ID, etc.
  comments: array<comment>,
  isResolved: bool,
  resolvedBy: option<userId>,
  resolvedAt: option<Js.Date.t>,
  createdAt: Js.Date.t,
}

type commentFilter = {
  showResolved: bool,
  authorFilter: option<userId>,
  mentionsMe: bool,
  hasAttachments: bool,
  dateRange: option<(Js.Date.t, Js.Date.t)>,
}

/**
 * Create a new comment
 */
let createComment = (
  ~threadId: threadId,
  ~author: userId,
  ~authorName: string,
  ~content: string,
  ~mentions: array<mentionType>=?,
  ~attachments: array<attachmentType>=?,
  ~parentId: option<commentId>=?,
  (),
): comment => {
  id: Js.Date.now()->Belt.Float.toString,
  threadId: threadId,
  author: author,
  authorName: authorName,
  content: content,
  mentions: mentions->Belt.Option.getWithDefault([]),
  attachments: attachments->Belt.Option.getWithDefault([]),
  reactions: [],
  createdAt: Js.Date.make(),
  updatedAt: None,
  isEdited: false,
  isResolved: false,
  parentId: parentId,
}

/**
 * Create a new comment thread
 */
let createThread = (
  ~documentId: string,
  ~anchorType: string,
  ~anchorRef: string,
  ~initialComment: comment,
  (),
): commentThread => {
  id: Js.Date.now()->Belt.Float.toString,
  documentId: documentId,
  anchorType: anchorType,
  anchorRef: anchorRef,
  comments: [initialComment],
  isResolved: false,
  resolvedBy: None,
  resolvedAt: None,
  createdAt: Js.Date.make(),
}

/**
 * Add comment to thread
 */
let addCommentToThread = (thread: commentThread, comment: comment): commentThread => {
  {
    ...thread,
    comments: thread.comments->Js.Array2.concat([comment]),
  }
}

/**
 * Edit comment
 */
let editComment = (comment: comment, newContent: string): comment => {
  {
    ...comment,
    content: newContent,
    updatedAt: Some(Js.Date.make()),
    isEdited: true,
  }
}

/**
 * Add reaction to comment
 */
let addReaction = (comment: comment, userId: userId, reaction: reactionType): comment => {
  // Remove existing reaction from this user if any
  let filteredReactions = comment.reactions->Js.Array2.filter(((uid, _)) => uid !== userId)

  {
    ...comment,
    reactions: filteredReactions->Js.Array2.concat([(userId, reaction)]),
  }
}

/**
 * Remove reaction from comment
 */
let removeReaction = (comment: comment, userId: userId): comment => {
  {
    ...comment,
    reactions: comment.reactions->Js.Array2.filter(((uid, _)) => uid !== userId),
  }
}

/**
 * Resolve thread
 */
let resolveThread = (thread: commentThread, resolvedBy: userId): commentThread => {
  {
    ...thread,
    isResolved: true,
    resolvedBy: Some(resolvedBy),
    resolvedAt: Some(Js.Date.make()),
  }
}

/**
 * Reopen thread
 */
let reopenThread = (thread: commentThread): commentThread => {
  {
    ...thread,
    isResolved: false,
    resolvedBy: None,
    resolvedAt: None,
  }
}

/**
 * Extract mentions from comment content
 */
let extractMentions = (content: string): array<mentionType> => {
  // Find @username patterns
  let mentionPattern = %re("/@(\w+)/g")

  let matches = []
  let rec findMatches = (str: string) => {
    switch Js.Re.exec_(mentionPattern, str) {
    | Some(result) => {
        let match = Js.Re.captures(result)[1]
        switch match {
        | Some(username) => {
            matches->Js.Array2.push(User(Js.Nullable.toOption(username)->Belt.Option.getExn))->ignore
            findMatches(str)
          }
        | None => ()
        }
      }
    | None => ()
    }
  }

  findMatches(content)

  // Check for @everyone
  if Js.String2.includes(content, "@everyone") {
    matches->Js.Array2.push(Everyone)->ignore
  }

  matches
}

/**
 * Filter comments based on criteria
 */
let filterComments = (threads: array<commentThread>, filter: commentFilter): array<commentThread> => {
  threads->Js.Array2.filter(thread => {
    // Resolved filter
    if !filter.showResolved && thread.isResolved {
      false
    } else {
      true
    }
  })
}

/**
 * Get comment count by author
 */
let getCommentCountByAuthor = (threads: array<commentThread>): Js.Dict.t<int> => {
  let counts = Js.Dict.empty()

  threads->Js.Array2.forEach(thread => {
    thread.comments->Js.Array2.forEach(comment => {
      let current = counts->Js.Dict.get(comment.author)->Belt.Option.getWithDefault(0)
      counts->Js.Dict.set(comment.author, current + 1)
    })
  })

  counts
}

/**
 * Get threads mentioning user
 */
let getThreadsMentioningUser = (threads: array<commentThread>, userId: userId): array<commentThread> => {
  threads->Js.Array2.filter(thread => {
    thread.comments->Js.Array2.some(comment => {
      comment.mentions->Js.Array2.some(mention => {
        switch mention {
        | User(uid) => uid === userId
        | Everyone => true
        | _ => false
        }
      })
    })
  })
}

/**
 * Export comments to JSON
 */
let exportCommentsJSON = (threads: array<commentThread>): string => {
  Js.Json.stringifyAny(threads)->Belt.Option.getWithDefault("[]")
}

/**
 * Generate comment notification
 */
let generateNotification = (comment: comment, thread: commentThread): string => {
  let mentionText = if comment.mentions->Js.Array2.length > 0 {
    " and mentioned you"
  } else {
    ""
  }

  `${comment.authorName} commented on ${thread.anchorType} ${thread.anchorRef}${mentionText}: "${comment.content}"`
}

/**
 * Get unresolved threads count
 */
let getUnresolvedCount = (threads: array<commentThread>): int => {
  threads->Js.Array2.filter(t => !t.isResolved)->Js.Array2.length
}

/**
 * Get threads by anchor
 */
let getThreadsByAnchor = (threads: array<commentThread>, anchorRef: string): array<commentThread> => {
  threads->Js.Array2.filter(t => t.anchorRef === anchorRef)
}
