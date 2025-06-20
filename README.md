# 🛡️ Digital Warranty Contract

A Clarity smart contract that enables manufacturers to register products with digital warranties and allows customers to purchase products and file warranty claims within the coverage window.

## 🚀 Features

- 📦 **Product Registration**: Manufacturers can register products with warranty periods
- 💰 **Product Purchase**: Customers can purchase products with automatic warranty activation
- ⏰ **Coverage Window**: Warranties have time-based expiration using block heights
- 📋 **Warranty Claims**: File and process warranty claims within valid coverage periods
- 🔍 **Status Tracking**: Check warranty status and remaining coverage time
- 👨‍💼 **Manufacturer Controls**: Update prices and deactivate products

## 📋 Contract Functions

### Read-Only Functions

- `get-product(product-id)` - Get product details
- `get-purchase(product-id, buyer)` - Get purchase information
- `get-warranty-claim(claim-id)` - Get warranty claim details
- `is-warranty-valid(product-id, buyer)` - Check if warranty is still active
- `get-warranty-status(product-id, buyer)` - Get detailed warranty status
- `get-next-product-id()` - Get next available product ID
- `get-next-claim-id()` - Get next available claim ID

### Public Functions

- `register-product(name, warranty-period-blocks, price)` - Register a new product
- `purchase-product(product-id)` - Purchase a product and activate warranty
- `file-warranty-claim(product-id, description)` - File a warranty claim
- `process-warranty-claim(claim-id, status, resolution)` - Process a claim (manufacturer only)
- `deactivate-product(product-id)` - Deactivate a product (manufacturer only)
- `update-product-price(product-id, new-price)` - Update product price (manufacturer only)

## 🛠️ Usage Examples

### Register a Product (as manufacturer)
```clarity
(contract-call? .digital-warranty-contract register-product "Smartphone X1" u1000 u500000000)
```

### Purchase a Product
```clarity
(contract-call? .digital-warranty-contract purchase-product u1)
```

### Check Warranty Status
```clarity
(contract-call? .digital-warranty-contract get-warranty-status u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### File a Warranty Claim
```clarity
(contract-call? .digital-warranty-contract file-warranty-claim u1 "Screen cracked after normal use")
```

### Process a Claim (as manufacturer)
```clarity
(contract-call? .digital-warranty-contract process-warranty-claim u1 "approved" "Replacement device shipped")
```

## 🔧 Testing with Clarinet

```bash
clarinet console
```

```bash
clarinet test
```

## 📊 Key Concepts

- **Block-based Warranty**: Warranties expire after a specified number of blocks
- **Manufacturer Authorization**: Only product manufacturers can process claims
- **Purchase Validation**: STX payment required for product purchase
- **Coverage Window**: Claims can only be filed within valid warranty periods

## 🎯 Error Codes

- `u100` - Not authorized
- `u101` - Product not found
- `u102` - Warranty expired
- `u103` - Claim not found
- `u104` - Claim already processed
- `u105` - Invalid warranty period
- `u106` - Product already exists

## 🏗️ Built With

- Clarity Smart Contract Language
- Clarinet Development Environment
- Stacks Blockchain
```

**Git Commit Message:**
```
feat: implement digital warranty contract MVP with product registration and claims
```

**GitHub Pull Request Title:**
```
🛡️ Add Digital Warranty Contract MVP
```

**GitHub Pull Request Description:**
```
## Summary
Added a complete Digital Warranty Contract implementation that demonstrates product purchase and warranty coverage windows.

## Features Added
- Product registration system for manufacturers
- STX-based product purchasing with automatic warranty activation
- Block-based warranty expiration system
- Warranty claim filing and processing workflow
- Manufacturer controls for product management
- Comprehensive warranty status tracking

## Technical Details
- 150+ lines of clean Clarity code
- 8 read-only functions for data access
- 6 public functions for core functionality
- Proper error handling with descriptive error codes
- Time-based warranty validation using block heights

## Files Added
- `contracts/digital-warranty-contract.clar` - Main contract implementation
- `README.md` - Complete documentation with usage examples

This MVP provides a solid foundation for understanding product warranties on blockchain with clear purchase-to-claim workflows.