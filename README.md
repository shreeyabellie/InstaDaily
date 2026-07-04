# InstaDaily
Scheduling a regular order interface system 

1. Organization Overview
1.1 Nature of Business

Swiggy Instamart is the quick commerce (Q-commerce) service of Swiggy Ltd., one of India's leading online delivery companies. It was launched in August 2020 during the COVID-19 pandemic to help people get groceries and daily essentials delivered quickly.
Unlike regular e-commerce companies that store products in large warehouses far away, Instamart uses small local warehouses called dark stores. These dark stores are located within 2–3 km of residential areas, allowing orders to be delivered in just 10–20 minutes.
As of December 2025 , Instamart has 1,136 dark stores in 131 cities across India. Every quarter, it processes around 106.4 million orders from 12.8 million monthly active users, with a gross order value of ₹7,938 crore. This is more than twice the value recorded in the same quarter of the previous year.
Today, Instamart is much more than a grocery delivery app. It has expanded by adding services like InsanelyGood for premium groceries, Swiggy Mall for products such as electronics and footwear, and Megapods, which are larger dark stores that stock up to 40,000 products. Because of these developments, Instamart has become a complete digital shopping platform where customers can buy groceries, household items, electronics, and many other products in one place.

1.2 Business Model

Instamart follows a dark store based quick commerce model to deliver products to customers quickly. Its business works through four main operational areas:
•	Dark Store Network: Instamart uses small warehouses called dark stores, which are located close to residential areas. Regular dark stores are around 1,500–3,000 sq. ft. and stock 2,000–3,000 products, while larger Megapods are 8,000–10,000 sq. ft. and can store up to 40,000 products. The products stocked in each store are selected based on local customer demand using AI and data analysis.
•	Hub-and-Spoke Delivery System: Large central warehouses (hubs) supply products to nearby dark stores (spokes). When customers place an order, the nearest dark store prepares it, and Swiggy's network of over 5.4 lakh delivery partners delivers it to the customer within minutes.
•	AI-Based Operations: Instamart uses Artificial Intelligence (AI) to predict customer demand, manage inventory, find the fastest delivery routes, set prices, detect fraud, and recommend products based on customer preferences.
•	Multiple Sources of Revenue: Instamart earns money in different ways. It makes profits from product sales, charges delivery fees, earns from advertisements and sponsored product listings, collects subscription fees through Swiggy One, and receives commissions from partner brands and sellers.

             
Revenue Stream	Description
Product Margin	Instamart earns a profit by selling products at a price higher than their purchase cost. The profit margin differs depending on the type of product.
Delivery Fees	Customers may be charged a delivery fee, especially for small-value orders or faster delivery services.
Advertising	Brands pay Instamart to promote their products through sponsored listings, banners, and featured offers. This advertising business has grown by about 40% year-on-year.
Swiggy One Subscription	Customers can subscribe to Swiggy One to get benefits like free food and grocery deliveries. This helps retain existing customers and encourages them to order more often.
Platform Fee	Instamart also charges a small platform fee of around ₹3–₹5 per order, which contributes significantly to its overall revenue.

Instamart is one of the biggest contributors to Swiggy's business, accounting for around 25% of the company's total Gross Merchandise Value (GMV) in FY2025. It is also the main driver of Swiggy's future growth.
To encourage customers to buy more items in a single order, Instamart introduced the MaxxSaver feature, which offers discounts on bundled purchases. As a result, the Average Order Value (AOV) increased from ₹460 in FY2024 to ₹746 in Q3 FY2026, showing that customers are spending more on each order.

1.3 Digital Business Ecosystem

Swiggy Instamart works with different groups of people and technologies that help the business run smoothly. These include customers, technology systems, warehouses, delivery partners, suppliers, payment services, and government regulations.
•	Customers: Customers use the Swiggy app or the Instamart app (launched in 2025) on their mobile phones to place orders. They can track their orders in real time, receive personalized product suggestions and offers, and manage their Swiggy One subscription.
•	Technology Infrastructure: Instamart uses Amazon Web Services (AWS) for cloud computing. It also uses AI tools such as Amazon Bedrock, Microsoft Fabric, and Microsoft Azure OpenAI to improve customer service, analyze data, and support business operations. In 2026, Swiggy introduced the Builders Club, which allows developers to create AI-based applications using its platform.
•	Dark Store Operations: Instamart's dark stores use a Warehouse Management System (WMS) to manage inventory, track products using QR codes, help workers pick items quickly, and prepare orders for fast delivery.
•	Delivery Partners: More than 5.4 lakh delivery partners use the Swiggy Partner app. The app helps them find the fastest routes, manage multiple orders, and track their delivery performance.
•	Suppliers and Merchants: FMCG companies, local suppliers, and private-label brands use the Merchant Partner Portal to update stock, promote products, and view sales reports.
•	Payment System: Customers can pay using UPI, debit cards, credit cards, digital wallets, or Swiggy Money. Instamart also uses secure payment systems and fraud detection to make online transactions safe.
•	Rules and Compliance: Instamart follows important government rules and regulations, including CERT-In cybersecurity guidelines, the Digital Personal Data Protection Act (DPDPA 2023) for protecting customer data, and FSSAI food safety standards.

1.4 Target Customers
Swiggy Instamart serves different types of customers based on their age, lifestyle, and shopping habits.
•	Urban Working Professionals (25–40 years): This is Instamart's main customer group. They have busy schedules and prefer quick delivery for groceries, household items, and other daily essentials, especially for urgent or last-minute purchases.
•	Tech-Savvy Millennials and Gen Z (18–30 years): Young customers enjoy fast delivery, attractive offers, and a smooth app experience. They actively use Swiggy One membership, MaxxSaver discounts, and other app features.
•	Families and Households: Families use Instamart for both weekly grocery shopping and emergency purchases. The larger Megapod stores provide a wide range of products, making it easy to buy everything in one place.
•	Students Living in Hostels or PGs: Students often order snacks, drinks, instant food, and personal care products in small quantities. They place orders frequently, even though they usually spend less per order.
•	Customers in Tier-2 Cities: Instamart is growing rapidly in smaller cities. By 2025, around 45% of Swiggy's active users came from Tier-2 and other developing cities, supported by the expansion of dark stores and marketing in local languages.
2. Information and Decision-Making
2.1 Data → Information → Knowledge → Wisdom (DIKW)
The DIKW Pyramid shows how raw data is converted into meaningful information, useful knowledge, and finally into wise business decisions.
Level	Definition	Instamart Example
Data	Raw facts without meaning.	22,000 orders were placed on Wednesday at 7:32 PM in Koramangala.
Information	Data organized into useful facts.	Orders increase on Wednesday evenings, mainly for dairy products and snacks.
Knowledge	Understanding patterns from information.	Instamart knows it needs more dairy stock in South Bengaluru on Wednesday evenings.
Wisdom	Using knowledge to make better decisions.	Instamart stocks extra products before demand increases, without giving discounts.

2.2 Types of Data Generated

•	Transactional Data: Order IDs, SKU quantities, timestamps, payment modes, cart values, delivery addresses
•	Behavioral Data: Browse sessions, search queries, scroll depth, category affinity, re-order frequency, abandoned carts
•	Geospatial Data: Customer location, delivery partner GPS traces, dark store geo-fencing boundaries, traffic data
•	Operational Data: Dark store inventory levels (QR-scanned real-time), picker performance, order-to-dispatch time, delivery SLA adherence
•	Financial Data: Revenue per order, contribution margin, promotional discount burn, advertising spend and ROI
•	Supplier/Inventory Data: SKU expiry dates, reorder thresholds, supplier lead times, FMCG brand stock levels
•	Customer Feedback Data: In-app ratings, support chat transcripts, NPS scores, Play Store / App Store reviews

2.3 How Information Quality Affects Managerial Decisions

Information quality determines the accuracy, speed, and confidence of managerial decisions. Instamart's business built on a 10 minute delivery promise is acutely sensitive to poor information:
•	Accuracy: In the past, a 5–10 minute lag in inventory dashboard updates meant customers ordered out-of-stock items. After deploying Microsoft Fabric Real Time Intelligence, inventory status now updates within seconds, reducing failed orders and customer complaints.
•	Timeliness: Demand forecasting models that run on stale data (e.g., yesterday's orders) cause stockouts during flash events (IPL matches, Diwali). Real-time data pipelines allow same-hour inventory adjustments.
•	Completeness: Incomplete geospatial data on new residential towers leads to delivery-partner navigation failures. Swiggy's proprietary mapping dataset is continuously enriched with partner GPS telemetry to fill these gaps.
Reliability: Coupon code misuse detected via Fabric RTI allowed Swiggy to discontinue leaked promotional codes within minutes, protecting revenue that would have otherwise been lost to coupon fraud on social media
2.4 Operational vs. Strategic Decisions

Operational Decisions (Daily Decisions)
•	Assign the nearest delivery partner to an order.
•	Refill fast-selling products when stock is low.
•	Block fake or suspicious coupon usage.
•	Change delivery routes during rain or traffic.
Strategic Decisions (Long-Term Decisions)
•	Open larger Megapod dark stores to offer more products.
•	Launch MaxxSaver to encourage bigger orders.
•	Expand services to Tier-2 cities based on customer demand.
•	Make Instamart a separate brand to strengthen its identity.
3. Business Information Systems Analysis
     3.1 Transaction Processing Systems (TPS)
            TPS handle the real-time recording and processing of Instamart's core business                                                                                                                                       
             Transactions.
             Every customer action triggers multiple TPS events:
•	Order Management System (OMS): Captures every order event  placement, confirmation, modification, cancellation  and distributes tasks to dark stores and delivery partners in milliseconds.
•	Payment Processing System: Integrates UPI rails (NPCI), card payment gateways and Swiggy Money. Processes payment authorization, settlement, refunds, and fraud flags.
•	Inventory Management System (IMS): Updates real-time stock levels via QR-code scanning at dark stores. Triggers auto-replenishment orders when SKU thresholds are breached.
•	Delivery Tracking System: Logs every GPS event from delivery partner devices, updating estimated delivery time (EDT) for customers in real time.

 3.2 Management Information Systems (MIS)
MIS aggregate TPS data into structured reports for operational managers. Instamart's MIS layer runs on Microsoft Fabric Real-Time Intelligence dashboards and custom BI tools:
•	Dark Store Manager Dashboard: Displays order queue depth, picker productivity (orders/hour), SKU stockout rate, and shift performance metrics. Previously updated every 5–10 minutes; now near-real-time.
•	City Operations Dashboard: Aggregates delivery SLA adherence, cancellation rates, customer complaint volumes, and partner availability across all dark stores in a city.
•	Financial Performance Reports: Daily, weekly, and monthly revenue, contribution margin, and advertising ROI reports for business unit heads.
•	Supplier & Inventory Reports: Tracks supplier fill-rate, SKU expiry risk, demand vs. supply gaps, and FMCG brand performance for category managers.

3.3 Decision Support Systems (DSS)
DSS at Instamart use AI/ML to support semi-structured decisions:
•	Demand Forecasting Engine: Analyzes historical order data, weather patterns, local events (IPL, festivals), and social trends to predict demand by SKU, time-slot, and location. Enables proactive stock positioning.
•	Dynamic Pricing Engine: Adjusts delivery fees and product pricing in real time based on demand elasticity, inventory surplus/shortage, and competitive pricing signals.
•	Route Optimization DSS: Assigns delivery partners to orders using multi-objective optimization (distance, traffic, SLA, partner capacity), reducing average delivery time and fuel cost.
•	Customer Churn Prediction: ML models identify customers at risk of churning and trigger retention interventions (personalized offers, push notifications, Swiggy One upgrade prompts).

•	Coupon Fraud Detection: Real-time anomaly detection flags unusually high usage of a single discount code and automatically disables it to protect promotional budgets.

3.4 Enterprise Systems
•	Cloud Infrastructure (AWS): Swiggy was born cloud-native on AWS in 2014. All microservices, databases, and ML pipelines run on AWS. Amazon Bedrock provides unified access to foundation models (Anthropic Claude, Meta LLaMA, Mistral) for AI features.
•	Data Platform (Microsoft Fabric RTI): Processes billions of operational data points daily for sub-second dashboard refreshes, real-time inventory updates, and coupon fraud detection.
•	CRM & Customer Engagement: Azure OpenAI automates the contact center (handling 'Where is my order?' queries without human agents), reducing support staffing costs at peak hours.
•	Orca Security Platform: Manages vulnerability detection across 10,000+ containers on AWS, providing risk-based prioritization to replace a previous avalanche of 5,000+ noisy security alerts.
•	Merchant Partner Portal: Web-based ERP interface for FMCG brands and suppliers to manage inventory, POs, sponsored placements, and campaign analytics.

3.5 E-Business Platforms
•	Swiggy Consumer App (iOS/Android): Primary customer interface offering browse, search, cart, checkout, tracking, and support in one unified UX.
•	Standalone Instamart App (launched 2025): Dedicated app for Instamart power users seeking a focused grocery-and-essentials experience without food-delivery navigation overhead.
•	Swiggy Builders Club API Platform (April 2026): Opens 3 MCP servers and 18+ API tools to approved developers and enterprises, enabling AI commerce agents to perform grocery ordering actions on Instamart programmatically.
•	Delivery Partner App: Mobile interface for gig workers to receive orders, navigate routes, confirm deliveries, and track earnings.
•	Dark Store Operations App: Tablet/mobile interface for store associates (pickers) featuring smart pick-route optimization, QR scanning, and order-status updates.

3.6 System Interaction Map
These systems form an integrated, event driven architecture: A customer order (TPS) triggers inventory checks (IMS), partner assignment (DSS), route planning (Route DSS), and real time tracking updates all simultaneously. MIS dashboards aggregate these events for managers, while enterprise AI systems (AWS Bedrock, Azure OpenAI) inject intelligence at each layer. The Merchant Portal and Builders Club API extend the ecosystem to external stakeholders.

4. Digital Business Workflow Analysis

This section describes the key workflows that underpin Instamart's operations. Visual diagrams (workflow, data flow, and business process maps) are presented in the accompanying PowerPoint presentation.
4.1 Order Fulfillment Process (Business Process Map)
Customer
   │
Browse Products
   │
Add to Cart
   │
Checkout
   │
Payment
   │
Order Sent to Dark Store
   │
Picking & Packing
   │
Delivery Partner Assigned
   │
Order Delivered
   │
Customer Feedback

4.2 Payment Processing Workflow
Customer
   │
Select Payment Method
   │
Payment Gateway
   │
Fraud Check
   │
Payment Approved?
 ┌──────┴──────┐
 │             │
Yes           No
 │             │
Order       Retry Payment
Confirmed

4.3 Customer Support Workflow
Customer
   │
Raise Complaint
   │
AI Chatbot
   │
Issue Solved?
 ┌──────┴──────┐
 │             │
Yes           No
 │             │
Close      Human Agent
               │
        Refund/Replacement
               │
          Customer Feedback

4.4 Inventory Update (Data Flow Diagram)
Customer Order
      │
 Dark Store
      │
Barcode Scan
      │
Inventory System
      │
Stock Updated
      │
Store Manager
      │
Supplier
 
<img width="975" height="471" alt="image" src="https://github.com/user-attachments/assets/6fea63e1-a93e-4112-817a-ef979291ad67" />


5. Strategic Advantage Through Digital Systems

5.1 Competitive Advantage
Instamart competes in a three-player market (Blinkit 40–45% share, Zepto 25–27%, Instamart 25–27%) and differentiates on:
•	Ecosystem Lock in: Swiggy One subscription bundles food delivery + grocery delivery free shipping, making users mathematically incentivized not to open a competing app. Shared logistics fleet across food and grocery reduces idle cost per vertical.
•	AOV Strategy: Unlike Blinkit and Zepto which compete on discount-led volume, Instamart's MaxxSaver and Megapod strategy targets higher AOV, with Q3 FY26 AOV of ₹746 vs industry average of ₹500.
•	Developer Ecosystem (Builders Club): Opening APIs to external developers creates a moat  third party AI agents built on Instamart's infrastructure deepen platform stickiness and reduce competitive substitutability.
•	Proprietary Hyperlocal Data: Years of geospatial order data from 131 cities is a defensive moat that new entrants cannot replicate quickly.

5.2 Customer Retention
•	Swiggy One Subscription: Acts as a retention flywheel  subscribers have free delivery on both food and grocery, increasing cross platform usage and 70%+ subscription renewal reluctance to leave.
•	Personalized Recommendations: AI models surface items based on past purchases, location, and time of day, increasing cart conversion and reducing search friction.
•	MaxxSaver Bundles: Reward customers for larger baskets with stacked discounts, creating a habitual 'load up' behavior that increases purchase frequency and AOV simultaneously.
•	Post Order Engagement: Automated 'reorder' prompts for perishable items (milk, bread, eggs) drive habitual repeat behavior without requiring customer initiative.

5.3 Automation
•	AI Dispatch: Zero human touch partner assignment and route optimization at scale across millions of daily orders.
•	Automated Contact Center: Azure OpenAI handles Tier 1 customer queries without adding headcount during mealtimes or demand spikes.
•	Auto-Replenishment: ML triggered supplier orders keep dark store shelves optimally stocked without manual stock checking by store managers.
•	Dynamic Coupon Management: Fabric RTI automatically disables leaked coupon codes within seconds, eliminating the need for manual monitoring.

5.4 Scalability
Instamart's cloud native AWS architecture allows horizontal scaling without infrastructure ceiling. During demand spikes (IPL finals, Diwali), compute resources scale automatically. The dark store model itself scales via capital: Swiggy enters 2026 with ₹4,605 Cr cash balance and plans to add Megapods at scale, with 50% of all new dark stores in Q2 FY26 being the large-format Megapod.

5.5 Personalization
AI personalization operates at three layers: (1) Homepage  curated product feeds based on purchase history and local trends; (2) Search  results ranked by personal affinity, not just keyword match; (3) Promotions targeted offers based on user segments (lapsing users get re engagement discounts; loyal users get early access to new SKUs). The Swiggy Builders Club API will extend this personalization to third party AI agents.

5.6 Operational Efficiency
•	Dark store pickers complete order fulfillment in 2–3 minutes, enabled by smart pick route optimization on the associate app.
•	Fleet utilization is maximized by routing the same delivery partner across food, grocery, and Genie deliveries throughout the day.
•	Microsoft Fabric RTI reduced operational dashboard lag from 5–10 minutes to near real time, enabling faster managerial interventions during service disruptions.
•	Megapods enable a tiered delivery model: grocery essentials in 10 minutes, non-grocery in 20 minutes, from a single location reducing dark store infrastructure cost per SKU served.

6. Challenges and Recommendations

6.1 Security Challenges
Swiggy's DRHP (2024) disclosed two significant security incidents:
•	September 2022: A technical infrastructure change exposed the last four digits of payment card details to some users, violating data minimization principles.
•	February 2023: A former employee fraudulently accessed test systems using retained credentials. An FIR was filed, but the incident highlighted insider threat vulnerabilities.
•	March 2024: CERT In flagged a potential data leak at a third party service provider. Swiggy confirmed its data was not compromised but acknowledged third party supply chain risk.
Additionally, Instamart's 10,000+ container environment on AWS creates a large attack surface. Before adopting Orca Security, the team was inundated with 5,000+ undifferentiated alerts, making critical vulnerability prioritization near impossible.

6.2 Privacy Concerns
Instamart collects deeply personal data: home address, purchase behavior (including medications, personal care, and dietary patterns), GPS traces, and payment information. Under India's Digital Personal Data Protection Act (DPDPA) 2023, Swiggy is obligated to obtain explicit consent, provide purpose limitation, and enable data erasure a compliance challenge given the volume and sensitivity of data collected.
As Swiggy's own DRHP states: 'The more personal data we hold, the greater the likelihood that a significant failure in our internal controls or data security measures could result in a data breach affecting more individuals.'

6.3 Data Management Issues
•	Data Silos: Instamart's inventory management system is purpose built and not fully integrated with Swiggy's food delivery TPS, creating reconciliation overhead for unified analytics.
•	Perishable SKU Management: Fresh produce and dairy require precise demand forecasting; over-forecasting creates wastage; under forecasting creates stockouts. Both erode margins and customer trust.
•	Unstructured Data: Customer support chat transcripts, driver feedback, and review text constitute vast unstructured data assets that are underutilized for operational insight.

6.4 Analysis of Instamart Interface Problems
Based on user feedback and app reviews, Swiggy Instamart has a few interface challenges that affect the overall shopping experience.
•	Complex navigation: The app has many product categories, making it difficult for new users to find products quickly.
•	Search is not personalized: Frequently purchased items are not shown first, so users may need to search longer.
•	Limited filter and sort options: The search results have fewer filtering options compared to competitors like BigBasket.
•	Less product information: Some product pages do not provide enough details such as ingredients, nutrition facts, or related products.
•	No order editing: Customers cannot add or remove items after placing an order, even for a short period.
•	Performance during peak hours: The app may become slower during busy times, leading to a poor user experience.
•	Basic account page: The profile section could better display order history, rewards, and quick reorder options.
6.5 Instadaily - The Calm Way to Run Your Home
1. The Problem: Speed Without Sanity
Quick-commerce platforms promise convenience, but they’ve created a new kind of stress.
The moment users open these apps, they’re bombarded with flashing banners, endless discounts, pop-ups, and urgency cues. Instead of making shopping easier, the experience demands constant attention and decision making.
Users are expected to:
•	Remember what’s already finished at home 
•	Decide what’s healthy versus what’s just convenient 
•	Plan for tomorrow while ordering for today 
•	And worst of all, live with regret when they forget something after checkout 
Grocery shopping has quietly become a cognitive burden.
It’s no longer just about buying food it’s about managing memory, health, and planning, all at once.

2. The Solution: Instadaily
Instadaily is a next generation quick-commerce platform built around one simple idea:
What if grocery shopping felt calm instead of chaotic?
Instadaily doesn’t ask users to think harder  it thinks with them.
It works quietly in the background to support everyday decisions, reduce mental friction, and forgive human mistakes. Instead of overwhelming users with choices, Instadaily focuses on clarity, continuity, and care.
This isn’t just faster delivery.
It’s a smarter, more humane way to run a household.

3. What Makes Instadaily Different
1. The Zen Homepage  Less Noise, More Clarity
Most apps treat the homepage like a billboard. Instadaily treats it like a calm entry point.
When users open Instadaily, they see:
•	Their regular essentials upfront 
•	One-tap reordering for frequently bought items 
•	Browsing, deals, and discovery placed separately  not forced 
The interface is clean, intentional, and distraction free.
Why it matters:
A calmer homepage reduces decision fatigue, speeds up ordering, and makes users want to return.
People don’t abandon the app because it’s slow  they abandon it because it’s exhausting.

2. The “Oops” Window Because Humans Forget
Everyone has experienced this moment:
You place the order, and immediately realize you forgot milk.
Instadaily fixes this with a simple but powerful feature.
For 60 seconds after checkout, users can add forgotten items to the same order without extra delivery charges.
No penalties. No frustration. No guilt.
Why it matters:
This single feature builds emotional trust.
It makes the app feel understanding rather than transactional  and often increases order value without irritating the user.

3. The Wellness Hub Shopping That Matches Real Life
Instadaily understands that people aren’t just buying groceries they’re managing lifestyles.
Users can opt into wellness preferences such as:
•	High-protein 
•	Vegan or vegetarian 
•	Low-sugar 
•	Gut-friendly or clean label choices 
Product suggestions, bundles, and reminders adapt to these preferences automatically.
Why it matters:
Instead of pushing random products, Instadaily supports how users want to live.
This transforms the app from a delivery service into a daily wellness companion.

4. Smart Pantry  We Remember, So You Don’t Have To
Instadaily tracks regular purchase patterns and predicts when essentials are likely running low.
It then:
•	Sends gentle reminders 
•	Prepares a weekly essentials list 
•	Allows users to approve everything in one tap 
No lists. No mental math. No last-minute panic.
Why it matters:
This removes the invisible labor of remembering household needs.
For users, it means peace of mind.
For Instadaily, it means consistent engagement and predictable revenue.

4. The Bigger Picture
Instadaily isn’t trying to win on speed alone.
It’s winning on trust, habit, and emotional loyalty.
By reducing mental load, forgiving mistakes, and aligning with users’ lives, Instadaily becomes something rare in quick commerce:

References 
Amazon Web Services. (2026, April). Swiggy to launch Builders Club, giving developers and enterprises access to its AI commerce stack. https://press.aboutamazon.com/aws/2026/4/swiggy-builders-club
Inc42. (2025, December). Swiggy in 2025: Cash rich and ready for quick commerce battle. https://inc42.com/features/
International Journal of Progressive Research in Engineering, Management and Science. (2025, June). A case study on Swiggy Instamart.
Lapaas Litmus Research. (2026, March). Swiggy business model. https://litmus.lapaas.com/
MarkHub24. (2026, March). Swiggy Instamart's speed-focused digital campaigns. https://www.markhub24.com/
MediaNama. (2024, October). Swiggy confirms past data breach amid security concerns. https://www.medianama.com/
Microsoft Asia. (2025, December). Real-time intelligence: How India's Swiggy serves millions with Microsoft Fabric. https://news.microsoft.com/source/asia/
Miracuves. (2025, December). Business model of Swiggy: Complete strategy breakdown. https://miracuves.com/blog/business-model-of-swiggy/
NarrativN. (2026, April). Swiggy Instamart business model & revenue model explained. https://narrativn.com/swiggy-instamart-business-model-revenue-model/
Orca Security. (2025, October). Swiggy scales cloud security across 10,000+ containers. https://orca.security/resources/case-studies/swiggy/
ProdLab. (2023, January). UI comparison: BigBasket vs Swiggy Instamart. https://prodlab.substack.com/
Swiggy Ltd. (2024). Draft Red Herring Prospectus (DRHP). Securities and Exchange Board of India.
Swiggy Ltd. (2026, January). Q3 FY2026 Earnings Report (October–December 2025). NSE/BSE Filings.
Vinod, G. A. (2024, November). From Cart to Kitchen: Redesigning Swiggy Instamart. Medium.
WareIQ. (2026, January). How Swiggy Instamart is redefining quick commerce in 2026. https://wareiq.com/


