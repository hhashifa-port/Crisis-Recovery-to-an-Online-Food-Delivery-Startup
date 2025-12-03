# Data Analysis for a Crisis Recovery to an Online Food Delivery Start Up

This whole project are based on *codebasic* challenges [here](https://codebasics.io/challenges/codebasics-resume-project-challenge/23). <br>
You can see the report (dahsboard about this data analysis) [here](https://public.tableau.com/views/Codebasics-QuickBite/Dashboard3?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link).

## Problem Statement
QuickBite Express is a Bengaluru-based food-tech startup (founded in 2020) that connects customers with nearby restaurants and cloud kitchens.
In June 2025, QuickBite faced a major crisis. A viral social media incident involving food safety violations at partner restaurants, combined with a week-long delivery outage during the monsoon season, triggered massive customer backlash. Competitors capitalized with aggressive campaigns, worsening the situation.

## Challenges
QuickBite has allocated a major recovery budget, overhauled food safety protocols, and upgraded its delivery infrastructure.
- Customer Segments: Identify which customers can be recovered and which need new strategies. 
- Order Patterns: Analyse order trends to uncover behavioral changes across phases (pre-crisis, crisis, recovery). 
- Delivery Performance: Assess delivery times, cancellations, and SLA compliance to pinpoint operational gaps. 
- Campaign Opportunities: Recommend targeted initiatives to rebuild trust and loyalty across demographics. 
- Restaurant Partnerships: Predict which partnerships are most valuable for long-term retention. 
- Feedback & Sentiment: Monitor real-time ratings, reviews, and sentiment to guide ongoing recovery efforts.

## Data Preparation
From the dataset given, there are 7 tables: `dim_customer`, `dim_menu_item`, `dim_restaurant`, `fact_delivery_performance`, `fact_order_items`, `fact_orders`, `fact_ratings`. Each table has at least one foreign key or primary key.
With the use of PostgreSQL, dataset all been set. 
- At first, tables are imported to the server with the right data type and statue (whether each columns are PK/FK/anything else).
- Second, do the feature engineering in each tables, such as:
  - `pre_crisis` : to check whether the order happens before/after the crisis
  - return all columns with value of Y/N into 1/0
  - check the inconsistency of data qualitative
  - quantification the qualitative data (if its needed)
- After all tables are set, the `order_details` table are created as a full information that gathered all table with the smallest dimension: `order_id` (FK)
- Calculate the metrics such as RFM, and other aggregate function that might be needed in data analysis.
- Create customer segmentation based on the RFM scored and other characteristics that are defined by:
  - *Recoverable* Customer Segment  : valuable-customer that are affected by the crisis (either churned or dissatisfied)
  - *Strategy or Reward* are Needed  : loyal-customer that aren't affected by the crisis or post-crisis new customer
  - *Low Priority* on Recovery  : churn customer after crisis that rarely making order before crisis happens.
- `order_details` and `customer_segmentation` tables are imported to Tableau.
- There are quite many calculation fields used in Tableau to simplify the visualization.

## Insights from Data Visualization
Dashboard page one: <br>
![Dashboard-page-1](https://github.com/hhashifa-port/Crisis-Recovery-to-an-Online-Food-Delivery-Startup/blob/main/Quicbite-Dashboard-1.png) <br>
From the dashboard given above, we can see that the *crisis insident* that happened in the first of June, 2025 has greatly affected the decline in order volume, revenue, and SLA compliance. Three months after the crisis insident (September, 2025), there are only 7000 total orders; which is thirteen thousand lower than the usual order that happens before crisis **(-13,71K)**. These indicates that QuickBite need some movement so that the overall performance can at least bact to baseline level. <br>

Dashboard page two: <br>
![Dashboard-pag-2](https://github.com/hhashifa-port/Crisis-Recovery-to-an-Online-Food-Delivery-Startup/blob/main/Quicbite-Dashboard-2.png) <br>
Based on the order_details table, which contains all information abount each order for each customer, we can get the RFM score (before/after crisis and overall), customer satisfaction (based on sentiment score, rating given, review), and other aggregate function. <br>

Here, we divided customer into four segments:
- Recoverable: valuable-customer that are affected by the crisis (either churned or dissatisfied)
  - **High-Value Drop-Off (59%)** <br>
    This was the largest segment, which contains most valuable customer but end up to be churners (those who had high Monetary and Frequency values before crisis occured). We really need to make an effort to gain them back. So they are became our first priority to the the recover strategy.
  - Mid-Value Drop-Off
  - Loyal Retained but Dissatisfied
- Strategy or Reward: loyal-customer that aren't affected by the crisis or post-crisis new customer
  - Retained Loyal <br>
    As a *thankful* and *treat*, we need to give them a reward, because they are still loyal even though we face the crisis
  - New Post-Crisis Customers <br>
    We should make a strategy to ensure that they got a delicate orders/services
  - New Post-Crisis Customers but Dissatisfied <br>
    Early improvisation must be done immediately <br>
- Low Priority: churn customer after crisis that rarely making order before crisis happens
  - Low-Value Drop-Off <br>
    Not our priority to do the recover strategy

Dashboard page three: <br>
![Dashboard-pag-3](https://github.com/hhashifa-port/Crisis-Recovery-to-an-Online-Food-Delivery-Startup/blob/main/Quicbite-Dashboard-3.png) <br>
What makes customer choose to be a churners of having a dissatisfied review as a result of the crisis insident? <br>
- Delivery services <br>
  It shows that the actual delivery time most likely slower than it should be (expected delivery time). This can affect the decline of customer satisfaction, and also the quality of the delivery food.
- Restaurant performance <br>
  There a huge decline for restaurant rating after crisis occured (the highest rating is only in between two.. something)

Those decline in delivery and restaurant partner performance resulted in customer dissatisfaction that can be seen from bad ratings, sentiment, and review (customer's complaint); and the most frequent complaints are related to **Food quality is not good**.

## What should QuickBite do to overcome this situation?
- **Recoverable Segment** — our priority, do this immediately
  - High-Value Drop-Off <br>
    - Mission: winning back high-value customers that became a churners after crisis occured
    - Strategy: personalized re-engagement and trust reset
    - Example: exclusive offers (large discount coupons/free delivery orders, personalized email to acknowledging the incident (emphasizing the new food safety protocal upgrades, and expressing sincere apologies)
  - Mid-Value Drop-Off <br>
    Win-Back program (discount that focusing on fast re-activation), promote a curated (and recommended) list of restaurant partners
  - Loyal Retained but Dissatisfied <br>
    - Mission: rectifying the experience of loyal customers who stayed but were dissapointed.
    - Strategy: service recovery and acknowledgment
    - Example: special discount as an apology for their bad experience, make their complaints as our priority and give a feedback that related to it
- Strategy or Reward — loyalty building
  - Retained Loyal
    - Mission: rewarding loyal customers who were *unaffected* by the crisis
    - Strategy: reward as a *thankful loyalty treat*
    - Example: Loyalty treatment (upgrade customer status with access to exclusive coupons, priority customer support, or a monthly reward), and send them the acknowledgment gift saying thankful for them for their loyalty during our hard time
  - New Post-Crisis Customers
    - Mission: ensuring they have a positive initial experience to build trust
    - Example: new joiner package (discount/free delivery that focused on short-term retention), trust building (acknowledge about new food safety protocols and improvement in delivery performance)
  - New Post-Crisis Customers but Dissatisfied
    - Mission: addressing immediate issues for new customers upon their first purchase
    - Example: prioritize complaints from this segment with early problem improvement, and then follow up with a free item or other treats
- Low Priority Segment — for efficiency
  - Mission: acknoledging the loss of this segment but not our priority
  - Example: general email campaigns, offer a standard re-activation coupon without personalization
