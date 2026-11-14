Requirements: Windows 10 or 11 and Chrome or Edge. Nothing to install.
First run: unzip the folder anywhere (not inside the zip preview), then
double-click "Start TCG Importer.bat". If Windows shows "Windows protected
your PC", click More info > Run anyway. A black window starts minimized on
the taskbar; leave it open (minimized is fine) while
you use the tool. Each person builds their own catalog with "Build catalog…".

TCG Import Builder
==================

Double-click "Start TCG Importer.bat". It opens the tool in your browser at
http://localhost:8765. Keep the black window open while you use it; close it
to stop. (Opening the .html file directly also works, but without most images.)

1. Get the catalog (once per set, redo when new sets drop)
   Easiest: click "Build catalog…", pick the game and sets, click Build.
   It pulls every card and its TCGplayer IDs straight from TCGplayer (cached
   in the "cache" folder). Prices come in for Near Mint; played cards are
   priced from Near Mint by the condition rule below.
   Ticked sets stay ticked, and Build skips sets you already have (tick
   "Rebuild loaded sets" to redo them). Lookups retry automatically; anything that still
   fails (bad connection) shows up under "Retry failed (N)" in that window,
   which reruns only those cards.
   When a build finishes, a pop-up says so and plays a short chime. If you're in
   another window, you also get a Windows notification (allow it the first time
   Chrome asks) and the tab title blinks.
   Or, the original way:
   TCGplayer Seller Portal > Pricing > Export Filtered CSV > pick the Category
   (and Sets if the whole game is too large) > leave "Export only from Live
   Inventory" unchecked > Export Filtered CSV.
   Drag the CSV(s) onto the tool. It remembers them in this browser.
   This file is where the TCGplayer SKU IDs come from, which the import needs.

2. Add cards
   Type short names: "bolt 2x2", "4 luke sor", "v corp". Leading number = quantity.
   Up/Down picks the printing, Enter or the Add button adds Near Mint (or NM
   Foil if "Default to foil" is on). For another condition, pick it in the
   dropdown next to Add; it goes back to Near Mint after each add.
   Edit quantity and price in the list on the right.
   "Open list CSV" (or drop a CSV on the right-hand panel) loads a saved list
   back in: one of this tool's exports, or a TCGplayer Live/Staged inventory
   export. Quantity comes from "Add to Quantity", or "Total Quantity" if that
   is empty; price from "TCG Marketplace Price". Duplicates are added together.

3. Export and import
   Export CSV, then in Seller Portal > Pricing > Import CSV, choose
   "Import to Staged" first and check it.
   "Add to Quantity" is ADDED to what you already have listed.
   "TCG Marketplace Price" REPLACES the listing price for that SKU.

Default price = TCG Low Price x % (or Market, top right), never below the floor ($0.50).
   Search results and the list show whichever price that setting uses.
Played cards are priced off the Near Mint copy (same finish), minus 10% per
step: Lightly Played 90%, Moderately 80%, Heavily 70%, Damaged 60%.
The floor also applies on Export, including prices you typed or loaded.
When a Near Mint card is added, its price refreshes from the day's TCGplayer
prices (unless you already typed a price for that line).
MTG set codes (2X2, M10...) load from Scryfall when online. Star Wars Unlimited
codes (SOR, SHD, TWI, JTL, LOF) are built in. Cyberpunk uses set-name words.

Image preview
   The highlighted card's image shows beside the results (click a card in your
   list to see its image too). Images come from TCGplayer's own product images
   (looked up through tcgcsv.com by the small local server), falling back to
   Scryfall for Magic and swu-db for Star Wars Unlimited. Needs internet.
   Lookups are cached in the "cache" folder. If no image is found, use
   the "Search on TCGplayer" link under the preview.

Exports folder
   After an export, a note offers to clear the list once the batch is imported.
   Exporting cards that already went out in an earlier batch asks first, since
   importing them again adds their quantities again.
   Each Export CSV also saves a copy in the "exports" folder next to this file
   (when started with the .bat). To upload a batch: TCGplayer Seller Portal >
   Pricing > Import To Staged > choose the file > Continue. Check the staged
   cards, then Move To Live.
