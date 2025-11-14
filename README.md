This repo contains a (currently rough) API-enabled script to find the best trade routes in the game Eve Online.  
It uses a static list of Trade Hubs and Items, as well as API calls to CCP's own servers (the creators of the game, legal to do) to work out the best trade routes to make the most in-game money (ISK) per trade run.  
I currently have it highlighting anything that can fit in a Crane as purple, anything in an Orca orange, and anything in a Charon without colour (those are ship names).  
  
To use, run the scripts in this order;  
  `grab_sell_orders.sh && grab_buy_orders.sh && compute_best_trade.py`
