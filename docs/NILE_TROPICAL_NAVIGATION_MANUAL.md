# Nile Tropical Navigation Manual

## 1. Purpose

This manual explains how staff navigate the Nile Tropical web application and where each operational task is performed.

It is written for the current Nile Tropical application architecture:

- **Project:** Nile Tropical
- **Repository:** `odoema/niletropical`
- **Admin area:** Nile Admin / Operations Console
- **Customer area:** Nile Tropical storefront
- **Editorial area:** Publishing Studio + Editorial Calendar
- **Media area:** CMS Media Library

This manual is based on the navigation features now present on the publishing branch. It should be updated after any navigation or permission change.

---

## 2. Before using the Admin Console

1. Open the Nile Tropical application.
2. Sign in with an authorised staff account.
3. The application checks the account's database role before allowing access to administration.
4. Google sign-in does **not** by itself create an administrator. Administrative access comes from the application's role assignment.
5. If an account has no permitted admin role, it is not given access to the Admin Console.

### Main staff roles

| Role | Primary responsibility |
|---|---|
| Journalist | Create and prepare editorial/social content; submit work for review |
| Content Manager | Manage CMS and publishing content; prepare content for review |
| Manager | Review, approve, schedule and publish editorial items |
| Super Admin | Full administrative control, including management/security functions |
| Courier | Courier/shipment workspace rather than the Admin Console |

Publishing workflow permissions are enforced by the database as well as the user interface.

---

# 3. Customer navigation

The customer-facing application is organised around the shopping journey.

## Home

**Navigation:** Home

Use Home to:

- view the Nile Tropical introduction and featured presentation;
- enter the Shop;
- discover featured products;
- access customer-facing information.

### Main shopping path

**Home → Shop → Product → Checkout**

### Direct purchase path

**Home → Product → Buy Now → Checkout**

---

## Shop

**Navigation:** Shop

Use Shop to:

- browse products;
- filter/browse product categories;
- open a product;
- add products to the cart.

---

## Product

**Navigation:** Select a product

A product page provides the current product information supplied by the application backend.

Use:

- **BUY NOW** for an immediate purchase;
- **ADD TO CART** when continuing to shop.

---

## Cart

**Navigation:** Cart

Use Cart to:

- review selected products;
- confirm quantities;
- proceed to checkout.

---

## Checkout

**Navigation:** Checkout

Use Checkout to:

- provide customer information;
- provide delivery information;
- select an available delivery option;
- select an available payment method;
- submit the order.

The server is authoritative for prices, stock, delivery fees and order totals. Do not rely on a browser-displayed total as the source of truth.

---

## Order confirmation

After a successful order, the confirmation page provides the order number and payment/order information supplied by the server.

Keep the order number for tracking.

---

## Track Order

**Navigation:** Track Order

Use tracking to find an order using the supported order-number and customer verification details.

---

## Customer Account

The customer area includes:

- Account
- Orders
- Addresses
- Notifications

Use these pages for the customer's own account information and order history.

---

# 4. Admin Console navigation

After authorised staff sign in, the **Nile Admin — Operations Console** provides the operational navigation.

The navigation is intentionally divided by operational purpose.

## Dashboard

**Route:** `/admin`

Use Dashboard for the overall operational starting point.

Start here when you need a quick view before entering a specific work area.

---

# 5. Orders

**Navigation:** Orders

Use Orders to manage the order lifecycle.

Typical path:

**Orders → Select order → Order detail**

Order detail is the working area for reviewing an individual order and its operational state.

Where applicable, proof of delivery is accessed from the order.

---

# 6. Products

**Navigation:** Products

Use Products to manage the product catalogue.

Typical tasks:

- view products;
- create a product;
- edit a product;
- manage product information;
- open product-specific management.

## Product Images

**Navigation:** Product Images

Use this area for product image management.

Keep product imagery separate from general CMS/media assets so product catalogue assets remain easy to identify.

---

# 7. Inventory

**Navigation:** Inventory

Use Inventory for stock and inventory operations.

## Stock Adjustment

**Navigation:** Inventory → Stock Adjustment

Use this only for an intentional inventory adjustment.

Remember:

- zero stock can be a valid production state;
- stock must not be invented simply to make a product appear available;
- the order system remains server-authoritative.

---

# 8. Delivery

**Navigation:** Delivery

Use Delivery for shipment and delivery operations.

This is where staff move from order information into delivery execution and shipment management.

---

# 9. Customers

**Navigation:** Customers

Use Customers to:

- find a customer;
- open customer details;
- review customer-related operational information.

Typical path:

**Customers → Select customer → Customer detail**

---

# 10. COD

**Navigation:** COD

Use COD for cash-on-delivery reconciliation.

This area is for operational reconciliation rather than ordinary order browsing.

Typical path:

**COD → Review COD records → Reconcile**

---

# 11. CMS

**Navigation:** CMS

CMS is the main content-management entry point.

Use it when changing what customers see across the Nile Tropical website and store application.

The CMS dashboard contains:

- Pages
- FAQs
- Testimonials
- Videos
- Promotions
- Banners
- Media Library
- Publishing Studio
- Store App HERO
- Website Slots

---

# 12. Media Library

**Navigation:** Media Library

The Media Library is the central reusable CMS media area.

Use it to:

- upload images;
- preview media;
- organise media into CMS folders;
- copy public media URLs when required;
- safely remove unused media.

Available folders include:

- Website
- Banners
- Testimonials
- CMS media

### Important safety rule

An image currently assigned to a live website media slot is protected from deletion. Change the slot assignment first if the image must be removed.

### Quality control

Uploaded images are checked by the application's image-quality service before being accepted.

---

# 13. Publishing Studio

**Navigation:** Publishing Studio

Publishing Studio is the newsroom and social-media preparation workspace.

It is intended for journalists, content managers and authorised managers.

Use it to:

- create a publishing item;
- write the main editorial copy;
- set a headline/working title;
- set a slug;
- add a byline;
- record a source/attribution note;
- add tags;
- choose cover media;
- choose story media;
- prepare channel-specific copy;
- select publishing channels;
- schedule publication;
- set an embargo;
- submit content for review;
- review editorial history.

Supported content types include:

- Social media post
- News story
- Press release
- Announcement
- Photo story
- Video story

Supported channel planning includes:

- Website
- Facebook
- Instagram
- LinkedIn
- X
- YouTube
- WhatsApp
- Newsletter
- Press

---

# 14. Publishing workflow

The intended editorial workflow is:

**Draft → In Review → Approved → Scheduled → Published**

An item can also be archived.

### Journalist / Content Manager

Normally:

1. Create the item.
2. Add editorial content.
3. Select media.
4. Prepare channel copy.
5. Save as Draft.
6. Move to In Review when ready.

### Manager / Super Admin

Normally:

1. Open the item in review.
2. Check the content, attribution, media and channel plan.
3. Approve it.
4. Set publication time if scheduling.
5. Publish when the publication conditions are satisfied.

The database enforces the important workflow transitions. The interface is not the only security control.

### Embargo

If an embargo time is set, publication is blocked until the embargo has elapsed.

---

# 15. Channel-specific copy

Inside a publishing item:

1. Select the channels required.
2. Select the channel's **Copy** control.
3. Write the platform-specific version.
4. Save the channel version.
5. Repeat for other channels where needed.

This allows the same editorial item to have different copy for different audiences.

---

# 16. Publishing media

Inside a publishing item there are two media concepts:

### Cover media

Use **Choose cover media** to select the primary image associated with the item.

### Story media

Use **Choose story media** to select one or more reusable media assets.

The picker reads from the CMS Media Library rather than requiring journalists to type storage paths manually.

---

# 17. Editorial Calendar

**Navigation:** Editorial Calendar

The Editorial Calendar provides a month-based view of scheduled publishing items.

Use it to:

- see what is scheduled;
- identify busy publication days;
- open a day's scheduled items;
- review title, type, status, date/time and byline.

Typical planning path:

**Publishing Studio → Editorial Calendar**

---

# 18. Editorial history and audit trail

Open an existing publishing item and select the **history** icon.

The editorial history records events such as:

- created;
- updated;
- submitted;
- approved;
- rejected;
- scheduled;
- published;
- archived;
- channel changes.

The audit actor is taken from the authenticated session. A user cannot legitimately become another staff member simply by supplying another user's UUID in a client request.

---

# 19. Store App HERO

**Navigation:** CMS → Store App HERO

Use this area to manage the four images used by the shopping app's Home slider.

Do not confuse this with the public website's HERO slots.

---

# 20. Website Slots

**Navigation:** CMS → Website Slots

Use this area to control approved media assigned to important website locations.

The website presentation layer can read these CMS slot assignments rather than requiring a code deployment for every media replacement.

---

# 21. Reports

**Navigation:** Reports

Use Reports for operational reporting.

---

# 22. Analytics

**Navigation:** Analytics

Use Analytics for operational/business analysis exposed by the application.

---

# 23. Pricing

**Navigation:** Pricing

Use Pricing for pricing recommendations and review.

Suggested prices are not automatically production truth. Actual pricing should only be published through the authorised product/pricing workflow.

---

# 24. Notifications

**Navigation:** Notifications

Use the administration notification area for notification-related operational tasks.

---

# 25. Audit Log

**Navigation:** Audit Log

Use Audit Log for broader administrative activity records.

Publishing Studio's editorial history is more specific: it records the lifecycle of an individual publishing item.

---

# 26. Error Logs

**Navigation:** Error Logs

Use Error Logs when investigating application errors reported by the system.

A production error should be investigated rather than hidden with mock data or a client-side workaround.

---

# 27. Management

**Navigation:** Management

Use Management for authorised administrative management functions.

Access should remain restricted to the appropriate administrative roles.

---

# 28. Settings

**Navigation:** Settings

Use Settings for authorised application/administrative configuration.

---

# 29. Sign out and return to the storefront

The Admin Console footer provides:

- the signed-in staff account;
- **Customer site** — return to the storefront;
- **Sign out** — end the staff session.

---

# 30. Courier navigation

Courier users enter the separate Courier workspace rather than the full Admin Console.

Courier navigation includes:

- Courier Dashboard
- Courier History
- Shipment Detail

This keeps delivery execution separate from wider administrative functions.

---

# 31. Recommended daily navigation

### Store operations

**Dashboard → Orders → Order detail → Delivery**

### Stock operations

**Dashboard → Inventory → Stock Adjustment**

### Catalogue work

**Products → Product → Product Images**

### Customer support

**Customers → Customer detail**

### Cash-on-delivery reconciliation

**COD → Reconciliation**

### Website content

**CMS → Website Slots / Pages / Banners / Media Library**

### Store app presentation

**CMS → Store App HERO**

### Journalism / newsroom

**Publishing Studio → Draft → In Review → Manager Review → Approved → Scheduled/Published**

### Editorial planning

**Publishing Studio → Editorial Calendar**

### Investigating a problem

**Error Logs → identify issue → reproduce → repair → validate**

---

# 32. Navigation rules that protect production

1. Do not use destructive database resets in production.
2. Do not create fake production data merely to make a screen look populated.
3. Do not bypass role checks.
4. Do not treat client-submitted prices, stock or totals as authoritative.
5. Do not delete CMS media that is actively assigned to a protected website slot.
6. Do not publish editorial material without the required workflow approval.
7. Do not treat a successful deployment build as proof that production is working.
8. After a deployment, verify the real website, store application and backend.
9. Keep Flutterwave as legacy/reference only; it is not part of the current payment architecture.

---

# 33. Deployment status note

This navigation manual is prepared against the **feature/publishing-studio-complete** branch.

The navigation enhancement added direct Admin Console entries for:

- Publishing Studio
- Editorial Calendar

The feature branch must still pass the project's normal validation and deployment gates before these changes are considered live production navigation.

Production certification remains:

**Identify → Baseline → Audit → Reconcile → Implement → Validate → Build → Deploy → Verify → Certify**
