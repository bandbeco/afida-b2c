class OptimizeCategorySeoMetadata < ActiveRecord::Migration[8.1]
  def up
    # Optimized based on Semrush UK keyword volume data (March 2026)
    # Format: primary keyword | benefit/price signal | Afida
    # Titles ≤60 chars, descriptions ≤160 chars
    updates = {
      # "ice cream cups" 880/mo, "paper ice cream cups" 170/mo
      "ice-cream-cups" => {
        meta_title: "Ice Cream Cups | Paper Cups from £0.04/unit | Afida",
        meta_description: "Paper ice cream cups and dessert cups from £0.04/unit. Eco-friendly cups for gelato and frozen yogurt, 4oz to 10oz. Free UK delivery over £100."
      },
      # "disposable coffee cups" 1,600/mo, "paper coffee cups" 720/mo, "coffee cups and lids" 320/mo
      "cups-and-lids" => {
        meta_title: "Disposable Coffee Cups & Lids | from £0.02 | Afida",
        meta_description: "Paper coffee cups and lids for cafes and takeaway. Single wall, double wall and ripple cups from £0.02/unit. Bulk pricing, free UK delivery over £100."
      },
      # "brown paper bags" 2,900/mo, "paper bags with handles" 1,300/mo, "paper bags wholesale" 480/mo
      "bags" => {
        meta_title: "Brown Paper Bags | Bags with Handles | Afida",
        meta_description: "Paper bags with handles for takeaway and retail from £0.01/unit. Brown paper bags, kraft carrier bags in all sizes. Free UK delivery over £100."
      },
      # "bagasse containers" 70/mo, "compostable food containers" 90/mo
      "bagasse-eco-range" => {
        meta_title: "Bagasse Containers | Compostable from £0.05 | Afida",
        meta_description: "Compostable bagasse food containers from £0.05/unit. Biodegradable sugarcane clamshells, burger boxes and eco takeaway bowls. Free UK delivery over £100."
      },
      # "takeaway containers" 1,000/mo, "takeaway bowls" 90/mo
      "takeaway-containers" => {
        meta_title: "Takeaway Containers | Eco Bowls from £0.07 | Afida",
        meta_description: "Eco-friendly takeaway containers and kraft salad bowls with lids from £0.07/unit. Biodegradable soup containers and food boxes. Free UK delivery over £100."
      },
      # "burger boxes" 1,300/mo, "takeaway food boxes" 480/mo, "kraft takeaway boxes" 170/mo
      "takeaway-boxes" => {
        meta_title: "Burger Boxes | Kraft Takeaway Boxes from £0.12 | Afida",
        meta_description: "Burger boxes and kraft takeaway food boxes from £0.12/unit. Cardboard chip boxes and carry out boxes for restaurants. Free UK delivery over £100."
      },
      # "wooden cutlery" 1,000/mo, "wooden forks" 480/mo
      "cutlery" => {
        meta_title: "Wooden Cutlery | Compostable from £0.08/unit | Afida",
        meta_description: "Disposable wooden cutlery for cafes and takeaways from £0.08/unit. Eco-friendly wooden forks, knives, spoons and cutlery kits. Free UK delivery over £100."
      },
      # "food containers" 4,400/mo
      "food-containers" => {
        meta_title: "Food Containers & Lids | from £0.04/unit | Afida",
        meta_description: "Disposable food containers with lids from £0.04/unit. Portion pots, deli containers and takeaway pots in PLA and compostable materials. Free delivery over £100."
      },
      # "paper plates" 6,600/mo, "disposable plates" 2,900/mo, "bamboo plates" 1,900/mo
      "plates-trays" => {
        meta_title: "Paper Plates | Disposable & Bamboo Plates | Afida",
        meta_description: "Paper plates, bamboo plates and disposable plates for catering and events. Bagasse plates, platter boxes and bowls. Eco-friendly, free UK delivery over £100."
      },
      # "paper straws" 1,600/mo, "biodegradable straws" 170/mo
      "straws" => {
        meta_title: "Paper Straws | Biodegradable from £0.02/unit | Afida",
        meta_description: "Biodegradable paper straws from £0.02/unit. Plastic-free compostable straws in white, black and striped options. Bulk pricing, free UK delivery over £100."
      },
      # "serviettes" 2,400/mo, "paper napkins" 1,900/mo, "cocktail napkins" 720/mo
      "napkins" => {
        meta_title: "Paper Napkins & Serviettes | Bulk UK | Afida",
        meta_description: "Paper napkins and serviettes for restaurants, cafes and events. Cocktail napkins, dinner napkins and luxury airlaid options. Free UK delivery over £100."
      },
      # "pizza box" 6,600/mo, "pizza boxes" 2,900/mo
      "pizza-boxes" => {
        meta_title: "Pizza Boxes | Kraft 7 to 16 Inch | Bulk UK | Afida",
        meta_description: "Kraft pizza boxes in all sizes from 7 to 16 inch. Recyclable corrugated pizza boxes for pizzerias and takeaway. Bulk pricing, free UK delivery over £100."
      },
      # "takeaway accessories" 20/mo — low volume but covers misc products
      "takeaway-extras" => {
        meta_title: "Takeaway Accessories | Bags & Cup Carriers | Afida",
        meta_description: "Paper bags with handles, wooden cutlery and cup carriers for takeaway. Brown paper bags and eco-friendly accessories. Free UK delivery over £100."
      }
    }

    updates.each do |slug, attrs|
      category = Category.find_by(slug: slug)
      next unless category

      category.update_columns(attrs)
    end
  end

  def down
    # Intentionally left blank — previous values can be restored from categories.csv
  end
end
