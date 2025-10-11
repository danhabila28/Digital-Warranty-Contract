(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PRODUCT_NOT_FOUND (err u101))
(define-constant ERR_WARRANTY_EXPIRED (err u102))
(define-constant ERR_CLAIM_NOT_FOUND (err u103))
(define-constant ERR_CLAIM_ALREADY_PROCESSED (err u104))
(define-constant ERR_INVALID_WARRANTY_PERIOD (err u105))
(define-constant ERR_PRODUCT_ALREADY_EXISTS (err u106))
(define-constant ERR_TRANSFER_NOT_AUTHORIZED (err u107))
(define-constant ERR_TRANSFER_TO_SELF (err u108))
(define-constant ERR_EXTENSION_NOT_ALLOWED (err u109))
(define-constant ERR_INVALID_EXTENSION_PERIOD (err u110))
(define-constant ERR_INVALID_SERIAL (err u111))
(define-constant ERR_SERIAL_ALREADY_EXISTS (err u112))
(define-constant ERR_SERIAL_NOT_FOUND (err u113))
(define-constant ERR_REFUND_PERIOD_EXPIRED (err u114))
(define-constant ERR_ALREADY_REFUNDED (err u115))
(define-constant ERR_NO_REFUND_POLICY (err u116))

(define-data-var next-product-id uint u1)
(define-data-var next-claim-id uint u1)

(define-map products
  { product-id: uint }
  {
    name: (string-ascii 100),
    manufacturer: principal,
    warranty-period-blocks: uint,
    price: uint,
    active: bool,
    refund-grace-blocks: uint
  }
)

(define-map purchases
  { product-id: uint, buyer: principal }
  {
    purchase-block: uint,
    warranty-expires: uint,
    purchase-price: uint
  }
)

(define-map warranty-claims
  { claim-id: uint }
  {
    product-id: uint,
    claimant: principal,
    claim-block: uint,
    description: (string-ascii 500),
    status: (string-ascii 20),
    resolution: (optional (string-ascii 500))
  }
)

(define-map warranty-transfers
  { product-id: uint, transfer-block: uint }
  {
    from-owner: principal,
    to-owner: principal,
    transfer-price: uint
  }
)

(define-map warranty-extensions
  { product-id: uint, buyer: principal, extension-block: uint }
  {
    extension-blocks: uint,
    extension-cost: uint,
    new-expiry: uint
  }
)

(define-map product-serials
  { serial-number: (string-ascii 64) }
  {
    product-id: uint,
    manufacturer: principal,
    is-authentic: bool,
    creation-block: uint
  }
)

(define-map serial-purchases
  { serial-number: (string-ascii 64) }
  {
    buyer: principal,
    purchase-block: uint,
    warranty-expires: uint,
    purchase-price: uint
  }
)

(define-map product-refunds
  { product-id: uint, buyer: principal }
  {
    refund-block: uint,
    refund-amount: uint,
    refunded: bool
  }
)

(define-read-only (get-product (product-id uint))
  (map-get? products { product-id: product-id })
)

(define-read-only (get-purchase (product-id uint) (buyer principal))
  (map-get? purchases { product-id: product-id, buyer: buyer })
)

(define-read-only (get-warranty-claim (claim-id uint))
  (map-get? warranty-claims { claim-id: claim-id })
)

(define-read-only (is-warranty-valid (product-id uint) (buyer principal))
  (match (get-purchase product-id buyer)
    purchase-data
    (let ((base-expiry (get warranty-expires purchase-data))
          (extended-expiry (get-extended-warranty-expiry product-id buyer)))
      (>= extended-expiry stacks-block-height))
    false
  )
)

(define-read-only (get-extended-warranty-expiry (product-id uint) (buyer principal))
  (match (get-purchase product-id buyer)
    purchase-data
    (get warranty-expires purchase-data)
    u0
  )
)

(define-read-only (get-warranty-status (product-id uint) (buyer principal))
  (match (get-purchase product-id buyer)
    purchase-data
    (let 
      (
        (warranty-expires (get warranty-expires purchase-data))
        (blocks-remaining (if (>= warranty-expires stacks-block-height) 
                           (- warranty-expires stacks-block-height) 
                           u0))
      )
      (some {
        purchase-block: (get purchase-block purchase-data),
        warranty-expires: warranty-expires,
        blocks-remaining: blocks-remaining,
        is-active: (>= warranty-expires stacks-block-height),
        purchase-price: (get purchase-price purchase-data)
      })
    )
    none
  )
)

(define-read-only (get-next-product-id)
  (var-get next-product-id)
)

(define-read-only (get-next-claim-id)
  (var-get next-claim-id)
)

(define-read-only (get-current-warranty-owner (product-id uint))
  (match (get-product product-id)
    product-data
    (some (get manufacturer product-data))
    none
  )
)

(define-read-only (calculate-extension-cost (product-id uint) (extension-blocks uint))
  (match (get-product product-id)
    product-data
    (let ((base-price (get price product-data)))
      (/ (* base-price extension-blocks) (get warranty-period-blocks product-data))
    )
    u0
  )
)

(define-read-only (get-warranty-extension (product-id uint) (buyer principal) (extension-block uint))
  (map-get? warranty-extensions { product-id: product-id, buyer: buyer, extension-block: extension-block })
)

(define-read-only (get-product-serial (serial-number (string-ascii 64)))
  (map-get? product-serials { serial-number: serial-number })
)

(define-read-only (get-serial-purchase (serial-number (string-ascii 64)))
  (map-get? serial-purchases { serial-number: serial-number })
)

(define-read-only (verify-serial-authenticity (serial-number (string-ascii 64)))
  (match (get-product-serial serial-number)
    serial-data
    (get is-authentic serial-data)
    false
  )
)

(define-read-only (is-serial-warranty-valid (serial-number (string-ascii 64)))
  (match (get-serial-purchase serial-number)
    purchase-data
    (>= (get warranty-expires purchase-data) stacks-block-height)
    false
  )
)

(define-read-only (get-refund-status (product-id uint) (buyer principal))
  (map-get? product-refunds { product-id: product-id, buyer: buyer })
)

(define-read-only (is-refund-eligible (product-id uint) (buyer principal))
  (match (get-purchase product-id buyer)
    purchase-data
    (match (get-product product-id)
      product-data
      (let 
        (
          (grace-blocks (get refund-grace-blocks product-data))
          (purchase-block (get purchase-block purchase-data))
          (refund-deadline (+ purchase-block grace-blocks))
        )
        (and 
          (> grace-blocks u0)
          (<= stacks-block-height refund-deadline)
          (is-none (get-refund-status product-id buyer))
        )
      )
      false
    )
    false
  )
)

(define-public (register-product 
  (name (string-ascii 100))
  (warranty-period-blocks uint)
  (price uint)
  (refund-grace-blocks uint)
)
  (let ((product-id (var-get next-product-id)))
    (asserts! (> warranty-period-blocks u0) ERR_INVALID_WARRANTY_PERIOD)
    (asserts! (is-none (get-product product-id)) ERR_PRODUCT_ALREADY_EXISTS)
    
    (map-set products
      { product-id: product-id }
      {
        name: name,
        manufacturer: tx-sender,
        warranty-period-blocks: warranty-period-blocks,
        price: price,
        active: true,
        refund-grace-blocks: refund-grace-blocks
      }
    )
    
    (var-set next-product-id (+ product-id u1))
    (ok product-id)
  )
)

(define-public (purchase-product (product-id uint))
  (match (get-product product-id)
    product-data
    (let 
      (
        (warranty-expires (+ stacks-block-height (get warranty-period-blocks product-data)))
        (price (get price product-data))
      )
      (asserts! (get active product-data) ERR_PRODUCT_NOT_FOUND)
      
      (try! (stx-transfer? price tx-sender (get manufacturer product-data)))
      
      (map-set purchases
        { product-id: product-id, buyer: tx-sender }
        {
          purchase-block: stacks-block-height,
          warranty-expires: warranty-expires,
          purchase-price: price
        }
      )
      
      (ok {
        product-id: product-id,
        warranty-expires: warranty-expires,
        purchase-price: price
      })
    )
    ERR_PRODUCT_NOT_FOUND
  )
)

(define-public (file-warranty-claim 
  (product-id uint)
  (description (string-ascii 500))
)
  (let ((claim-id (var-get next-claim-id)))
    (asserts! (is-warranty-valid product-id tx-sender) ERR_WARRANTY_EXPIRED)
    
    (map-set warranty-claims
      { claim-id: claim-id }
      {
        product-id: product-id,
        claimant: tx-sender,
        claim-block: stacks-block-height,
        description: description,
        status: "pending",
        resolution: none
      }
    )
    
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

(define-public (process-warranty-claim 
  (claim-id uint)
  (status (string-ascii 20))
  (resolution (string-ascii 500))
)
  (match (get-warranty-claim claim-id)
    claim-data
    (let ((product-id (get product-id claim-data)))
      (match (get-product product-id)
        product-data
        (begin
          (asserts! (is-eq tx-sender (get manufacturer product-data)) ERR_NOT_AUTHORIZED)
          (asserts! (is-eq (get status claim-data) "pending") ERR_CLAIM_ALREADY_PROCESSED)
          
          (map-set warranty-claims
            { claim-id: claim-id }
            (merge claim-data {
              status: status,
              resolution: (some resolution)
            })
          )
          
          (ok true)
        )
        ERR_PRODUCT_NOT_FOUND
      )
    )
    ERR_CLAIM_NOT_FOUND
  )
)

(define-public (deactivate-product (product-id uint))
  (match (get-product product-id)
    product-data
    (begin
      (asserts! (is-eq tx-sender (get manufacturer product-data)) ERR_NOT_AUTHORIZED)
      
      (map-set products
        { product-id: product-id }
        (merge product-data { active: false })
      )
      
      (ok true)
    )
    ERR_PRODUCT_NOT_FOUND
  )
)

(define-public (update-product-price (product-id uint) (new-price uint))
  (match (get-product product-id)
    product-data
    (begin
      (asserts! (is-eq tx-sender (get manufacturer product-data)) ERR_NOT_AUTHORIZED)
      (asserts! (get active product-data) ERR_PRODUCT_NOT_FOUND)
      
      (map-set products
        { product-id: product-id }
        (merge product-data { price: new-price })
      )
      
      (ok true)
    )
    ERR_PRODUCT_NOT_FOUND
  )
)

(define-public (transfer-warranty (product-id uint) (to-owner principal) (transfer-price uint))
  (let ((current-owner tx-sender))
    (asserts! (not (is-eq current-owner to-owner)) ERR_TRANSFER_TO_SELF)
    (asserts! (is-warranty-valid product-id current-owner) ERR_WARRANTY_EXPIRED)
    
    (try! (stx-transfer? transfer-price to-owner current-owner))
    
    (map-set warranty-transfers
      { product-id: product-id, transfer-block: stacks-block-height }
      {
        from-owner: current-owner,
        to-owner: to-owner,
        transfer-price: transfer-price
      }
    )
    
    (match (get-purchase product-id current-owner)
      purchase-data
      (begin
        (map-delete purchases { product-id: product-id, buyer: current-owner })
        (map-set purchases
          { product-id: product-id, buyer: to-owner }
          purchase-data
        )
        (ok true)
      )
      ERR_PRODUCT_NOT_FOUND
    )
  )
)

(define-public (extend-warranty (product-id uint) (extension-blocks uint))
  (let 
    (
      (extension-cost (calculate-extension-cost product-id extension-blocks))
      (current-purchase (unwrap! (get-purchase product-id tx-sender) ERR_PRODUCT_NOT_FOUND))
      (current-expiry (get warranty-expires current-purchase))
      (new-expiry (+ current-expiry extension-blocks))
    )
    (asserts! (> extension-blocks u0) ERR_INVALID_EXTENSION_PERIOD)
    (asserts! (>= current-expiry stacks-block-height) ERR_EXTENSION_NOT_ALLOWED)
    
    (match (get-product product-id)
      product-data
      (begin
        (try! (stx-transfer? extension-cost tx-sender (get manufacturer product-data)))
        
        (map-set warranty-extensions
          { product-id: product-id, buyer: tx-sender, extension-block: stacks-block-height }
          {
            extension-blocks: extension-blocks,
            extension-cost: extension-cost,
            new-expiry: new-expiry
          }
        )
        
        (map-set purchases
          { product-id: product-id, buyer: tx-sender }
          (merge current-purchase { warranty-expires: new-expiry })
        )
        
        (ok {
          extension-blocks: extension-blocks,
          extension-cost: extension-cost,
          new-expiry: new-expiry
        })
      )
      ERR_PRODUCT_NOT_FOUND
    )
  )
)

(define-public (generate-product-serial (product-id uint) (serial-number (string-ascii 64)))
  (match (get-product product-id)
    product-data
    (begin
      (asserts! (is-eq tx-sender (get manufacturer product-data)) ERR_NOT_AUTHORIZED)
      (asserts! (is-none (get-product-serial serial-number)) ERR_SERIAL_ALREADY_EXISTS)
      (asserts! (> (len serial-number) u0) ERR_INVALID_SERIAL)
      
      (map-set product-serials
        { serial-number: serial-number }
        {
          product-id: product-id,
          manufacturer: tx-sender,
          is-authentic: true,
          creation-block: stacks-block-height
        }
      )
      
      (ok serial-number)
    )
    ERR_PRODUCT_NOT_FOUND
  )
)

(define-public (purchase-with-serial (serial-number (string-ascii 64)))
  (let ((serial-data (unwrap! (get-product-serial serial-number) ERR_SERIAL_NOT_FOUND)))
    (asserts! (get is-authentic serial-data) ERR_INVALID_SERIAL)
    (asserts! (is-none (get-serial-purchase serial-number)) ERR_SERIAL_ALREADY_EXISTS)
    
    (match (get-product (get product-id serial-data))
      product-data
      (let 
        (
          (warranty-expires (+ stacks-block-height (get warranty-period-blocks product-data)))
          (price (get price product-data))
        )
        (asserts! (get active product-data) ERR_PRODUCT_NOT_FOUND)
        
        (try! (stx-transfer? price tx-sender (get manufacturer product-data)))
        
        (map-set serial-purchases
          { serial-number: serial-number }
          {
            buyer: tx-sender,
            purchase-block: stacks-block-height,
            warranty-expires: warranty-expires,
            purchase-price: price
          }
        )
        
        (ok {
          serial-number: serial-number,
          warranty-expires: warranty-expires,
          purchase-price: price
        })
      )
      ERR_PRODUCT_NOT_FOUND
    )
  )
)

(define-public (verify-and-claim (serial-number (string-ascii 64)) (description (string-ascii 500)))
  (let ((claim-id (var-get next-claim-id)))
    (asserts! (verify-serial-authenticity serial-number) ERR_INVALID_SERIAL)
    (asserts! (is-serial-warranty-valid serial-number) ERR_WARRANTY_EXPIRED)
    
    (match (get-serial-purchase serial-number)
      purchase-data
      (begin
        (asserts! (is-eq tx-sender (get buyer purchase-data)) ERR_NOT_AUTHORIZED)
        
        (let ((serial-info (unwrap-panic (get-product-serial serial-number))))
          (map-set warranty-claims
            { claim-id: claim-id }
            {
              product-id: (get product-id serial-info),
              claimant: tx-sender,
              claim-block: stacks-block-height,
              description: description,
              status: "pending",
              resolution: none
            }
          )
        )
        
        (var-set next-claim-id (+ claim-id u1))
        (ok claim-id)
      )
      ERR_SERIAL_NOT_FOUND
    )
  )
)

(define-public (request-product-refund (product-id uint))
  (let 
    (
      (purchase-data (unwrap! (get-purchase product-id tx-sender) ERR_PRODUCT_NOT_FOUND))
      (product-data (unwrap! (get-product product-id) ERR_PRODUCT_NOT_FOUND))
    )
    (asserts! (is-none (get-refund-status product-id tx-sender)) ERR_ALREADY_REFUNDED)
    (asserts! (is-refund-eligible product-id tx-sender) ERR_REFUND_PERIOD_EXPIRED)
    
    (let 
      (
        (refund-amount (get purchase-price purchase-data))
        (manufacturer (get manufacturer product-data))
      )
      (try! (stx-transfer? refund-amount manufacturer tx-sender))
      
      (map-set product-refunds
        { product-id: product-id, buyer: tx-sender }
        {
          refund-block: stacks-block-height,
          refund-amount: refund-amount,
          refunded: true
        }
      )
      
      (map-delete purchases { product-id: product-id, buyer: tx-sender })
      
      (ok {
        product-id: product-id,
        refund-amount: refund-amount,
        refund-block: stacks-block-height
      })
    )
  )
)