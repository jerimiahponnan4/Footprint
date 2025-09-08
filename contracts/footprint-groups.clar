;; Carbon Footprint Groups & Challenges Contract
;; Enables users to form groups and create collaborative carbon reduction challenges

;; Error constants
(define-constant ERR_NOT_FOUND (err u200))
(define-constant ERR_UNAUTHORIZED (err u201))
(define-constant ERR_ALREADY_EXISTS (err u202))
(define-constant ERR_INVALID_INPUT (err u203))
(define-constant ERR_GROUP_FULL (err u204))
(define-constant ERR_CHALLENGE_ENDED (err u205))
(define-constant ERR_NOT_MEMBER (err u206))
(define-constant ERR_ALREADY_MEMBER (err u207))
(define-constant ERR_CHALLENGE_ACTIVE (err u208))

;; Data variables
(define-data-var next-group-id uint u1)
(define-data-var next-challenge-id uint u1)

;; Group data structures
(define-map groups
  { group-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 300),
    creator: principal,
    created-at: uint,
    member-count: uint,
    max-members: uint,
    total-emissions: uint,
    total-offsets: uint,
    net-footprint: int,
    is-active: bool
  }
)

(define-map group-members
  { group-id: uint, member: principal }
  {
    joined-at: uint,
    role: (string-ascii 20) ;; "creator", "admin", "member"
  }
)

;; Challenge data structures
(define-map challenges
  { challenge-id: uint }
  {
    group-id: uint,
    name: (string-ascii 100),
    description: (string-ascii 400),
    challenge-type: (string-ascii 30), ;; "reduce-emissions", "increase-offsets", "net-neutral"
    target-value: uint,
    start-block: uint,
    end-block: uint,
    reward-credits: uint,
    creator: principal,
    is-completed: bool,
    completion-percentage: uint
  }
)

(define-map challenge-participation
  { challenge-id: uint, participant: principal }
  {
    baseline-emissions: uint,
    baseline-offsets: uint,
    current-progress: uint,
    contribution-percentage: uint,
    joined-at: uint
  }
)

;; Group statistics tracking
(define-map group-stats
  { group-id: uint }
  {
    total-challenges: uint,
    completed-challenges: uint,
    total-rewards-earned: uint,
    best-net-footprint: int,
    most-active-month: uint
  }
)

;; Public functions

;; Create a new group
(define-public (create-group (name (string-ascii 100)) (description (string-ascii 300)) (max-members uint))
  (let (
    (group-id (var-get next-group-id))
    (creator tx-sender)
  )
    (asserts! (> (len name) u0) ERR_INVALID_INPUT)
    (asserts! (and (>= max-members u2) (<= max-members u100)) ERR_INVALID_INPUT)
    
    ;; Create group
    (map-set groups
      { group-id: group-id }
      {
        name: name,
        description: description,
        creator: creator,
        created-at: stacks-block-height,
        member-count: u1,
        max-members: max-members,
        total-emissions: u0,
        total-offsets: u0,
        net-footprint: 0,
        is-active: true
      }
    )
    
    ;; Add creator as first member
    (map-set group-members
      { group-id: group-id, member: creator }
      {
        joined-at: stacks-block-height,
        role: "creator"
      }
    )
    
    ;; Initialize group stats
    (map-set group-stats
      { group-id: group-id }
      {
        total-challenges: u0,
        completed-challenges: u0,
        total-rewards-earned: u0,
        best-net-footprint: 0,
        most-active-month: u0
      }
    )
    
    (var-set next-group-id (+ group-id u1))
    (ok group-id)
  )
)

;; Join an existing group
(define-public (join-group (group-id uint))
  (let (
    (member tx-sender)
    (group-data (unwrap! (map-get? groups { group-id: group-id }) ERR_NOT_FOUND))
  )
    (asserts! (get is-active group-data) ERR_NOT_FOUND)
    (asserts! (< (get member-count group-data) (get max-members group-data)) ERR_GROUP_FULL)
    (asserts! (is-none (map-get? group-members { group-id: group-id, member: member })) ERR_ALREADY_MEMBER)
    
    ;; Add member to group
    (map-set group-members
      { group-id: group-id, member: member }
      {
        joined-at: stacks-block-height,
        role: "member"
      }
    )
    
    ;; Update group member count
    (map-set groups
      { group-id: group-id }
      (merge group-data { member-count: (+ (get member-count group-data) u1) })
    )
    
    (ok true)
  )
)

;; Create a challenge for a group
(define-public (create-challenge 
  (group-id uint) 
  (name (string-ascii 100)) 
  (description (string-ascii 400))
  (challenge-type (string-ascii 30))
  (target-value uint)
  (duration-blocks uint)
  (reward-credits uint))
  (let (
    (challenge-id (var-get next-challenge-id))
    (creator tx-sender)
    (group-data (unwrap! (map-get? groups { group-id: group-id }) ERR_NOT_FOUND))
    (member-data (unwrap! (map-get? group-members { group-id: group-id, member: creator }) ERR_NOT_MEMBER))
  )
    (asserts! (get is-active group-data) ERR_NOT_FOUND)
    (asserts! (> (len name) u0) ERR_INVALID_INPUT)
    (asserts! (> target-value u0) ERR_INVALID_INPUT)
    (asserts! (and (>= duration-blocks u144) (<= duration-blocks u52560)) ERR_INVALID_INPUT) ;; 1 day to 1 year
    (asserts! (or (is-eq challenge-type "reduce-emissions") 
                  (is-eq challenge-type "increase-offsets") 
                  (is-eq challenge-type "net-neutral")) ERR_INVALID_INPUT)
    
    ;; Create challenge
    (map-set challenges
      { challenge-id: challenge-id }
      {
        group-id: group-id,
        name: name,
        description: description,
        challenge-type: challenge-type,
        target-value: target-value,
        start-block: stacks-block-height,
        end-block: (+ stacks-block-height duration-blocks),
        reward-credits: reward-credits,
        creator: creator,
        is-completed: false,
        completion-percentage: u0
      }
    )
    
    ;; Update group stats
    (let ((stats (default-to 
      { total-challenges: u0, completed-challenges: u0, total-rewards-earned: u0, best-net-footprint: 0, most-active-month: u0 }
      (map-get? group-stats { group-id: group-id }))))
      (map-set group-stats
        { group-id: group-id }
        (merge stats { total-challenges: (+ (get total-challenges stats) u1) })
      )
    )
    
    (var-set next-challenge-id (+ challenge-id u1))
    (ok challenge-id)
  )
)

;; Join a challenge
(define-public (join-challenge (challenge-id uint))
  (let (
    (participant tx-sender)
    (challenge-data (unwrap! (map-get? challenges { challenge-id: challenge-id }) ERR_NOT_FOUND))
    (group-id (get group-id challenge-data))
  )
    (asserts! (is-some (map-get? group-members { group-id: group-id, member: participant })) ERR_NOT_MEMBER)
    (asserts! (< stacks-block-height (get end-block challenge-data)) ERR_CHALLENGE_ENDED)
    (asserts! (is-none (map-get? challenge-participation { challenge-id: challenge-id, participant: participant })) ERR_ALREADY_MEMBER)
    
    ;; Record participation with baseline metrics (would integrate with main contract)
    (map-set challenge-participation
      { challenge-id: challenge-id, participant: participant }
      {
        baseline-emissions: u0, ;; Would get from main contract
        baseline-offsets: u0,   ;; Would get from main contract
        current-progress: u0,
        contribution-percentage: u0,
        joined-at: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Update group statistics (should be called when members update their footprints)
(define-public (update-group-stats (group-id uint))
  (let (
    (group-data (unwrap! (map-get? groups { group-id: group-id }) ERR_NOT_FOUND))
    (caller tx-sender)
  )
    (asserts! (is-some (map-get? group-members { group-id: group-id, member: caller })) ERR_NOT_MEMBER)
    
    ;; This would integrate with the main Footprint contract to aggregate member stats
    ;; For now, we'll update with placeholder logic
    (map-set groups
      { group-id: group-id }
      (merge group-data { 
        total-emissions: (get total-emissions group-data),
        total-offsets: (get total-offsets group-data),
        net-footprint: (get net-footprint group-data)
      })
    )
    
    (ok true)
  )
)

;; Check and complete challenges
(define-public (check-challenge-completion (challenge-id uint))
  (let (
    (challenge-data (unwrap! (map-get? challenges { challenge-id: challenge-id }) ERR_NOT_FOUND))
    (group-id (get group-id challenge-data))
  )
    (asserts! (>= stacks-block-height (get end-block challenge-data)) ERR_CHALLENGE_ACTIVE)
    (asserts! (not (get is-completed challenge-data)) ERR_ALREADY_EXISTS)
    
    ;; Calculate completion percentage (simplified logic)
    (let ((completion-pct u75)) ;; Would calculate based on actual progress
      (map-set challenges
        { challenge-id: challenge-id }
        (merge challenge-data { 
          is-completed: true,
          completion-percentage: completion-pct
        })
      )
      
      ;; Update group stats if successful
      (if (>= completion-pct u100)
        (let ((stats (unwrap! (map-get? group-stats { group-id: group-id }) ERR_NOT_FOUND)))
          (map-set group-stats
            { group-id: group-id }
            (merge stats { 
              completed-challenges: (+ (get completed-challenges stats) u1),
              total-rewards-earned: (+ (get total-rewards-earned stats) (get reward-credits challenge-data))
            })
          )
        )
        true
      )
      
      (ok completion-pct)
    )
  )
)

;; Read-only functions

(define-read-only (get-group (group-id uint))
  (map-get? groups { group-id: group-id })
)

(define-read-only (get-group-member (group-id uint) (member principal))
  (map-get? group-members { group-id: group-id, member: member })
)

(define-read-only (get-challenge (challenge-id uint))
  (map-get? challenges { challenge-id: challenge-id })
)

(define-read-only (get-challenge-participation (challenge-id uint) (participant principal))
  (map-get? challenge-participation { challenge-id: challenge-id, participant: participant })
)

(define-read-only (get-group-stats (group-id uint))
  (map-get? group-stats { group-id: group-id })
)

(define-read-only (is-group-member (group-id uint) (user principal))
  (is-some (map-get? group-members { group-id: group-id, member: user }))
)

(define-read-only (get-active-groups-count)
  (var-get next-group-id)
)

(define-read-only (get-total-challenges-count)
  (var-get next-challenge-id)
)

(define-read-only (is-challenge-active (challenge-id uint))
  (match (map-get? challenges { challenge-id: challenge-id })
    challenge (and (< stacks-block-height (get end-block challenge))
                   (not (get is-completed challenge)))
    false
  )
)
