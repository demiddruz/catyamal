-- Настройки магазина. Номера (id) берутся из Creator Dashboard после публикации игры:
-- Monetization → Passes (пропуски) и Monetization → Developer Products (покупки). Пока id = 0, кнопка показывает «скоро».
return {
	Passes = {
		DoubleCoins = { id = 0, price = 99, name = "Двойные монеты", desc = "Все монеты ×2 навсегда" },
		ExtraHeart = { id = 0, price = 149, name = "Четвёртое сердечко", desc = "4 жизни вместо 3" },
		GoldKit = { id = 0, price = 49, name = "Золотая форма", desc = "Открывает золотую форму Барсы" },
		VIP = { id = 0, price = 199, name = "VIP", desc = "Значок VIP и 1 заряд льда с начала уровня" },
	},
	PassOrder = { "DoubleCoins", "ExtraHeart", "GoldKit", "VIP" },
	Products = {
		Coins100 = { id = 0, price = 25, coins = 100, name = "100 монет" },
		Coins500 = { id = 0, price = 99, coins = 500, name = "500 монет" },
		Coins1500 = { id = 0, price = 249, coins = 1500, name = "1500 монет" },
		Revive = { id = 0, price = 15, name = "Воскреснуть на месте" },
		Energy = { id = 0, price = 10, name = "Полная энергия" },
	},
	ProductOrder = { "Coins100", "Coins500", "Coins1500", "Energy" },
	-- формы: за монеты из игры (coins) или по пропуску (pass)
	Kits = {
		{ key = "barca", name = "Барса", coins = 0, torso = { 29, 63, 143 }, stripe = { 163, 25, 58 }, legs = { 0, 77, 152 }, text = { 237, 187, 0 } },
		{ key = "away", name = "Гостевая", coins = 200, torso = { 245, 245, 245 }, stripe = { 225, 225, 225 }, legs = { 245, 245, 245 }, text = { 163, 25, 58 } },
		{ key = "black", name = "Чёрная", coins = 300, torso = { 22, 22, 26 }, stripe = { 52, 52, 58 }, legs = { 22, 22, 26 }, text = { 255, 215, 0 } },
		{ key = "sky", name = "Небесная", coins = 400, torso = { 127, 216, 255 }, stripe = { 255, 255, 255 }, legs = { 29, 63, 143 }, text = { 29, 63, 143 } },
		{ key = "gold", name = "Золотая", pass = "GoldKit", torso = { 255, 215, 0 }, stripe = { 230, 175, 0 }, legs = { 255, 255, 255 }, text = { 29, 63, 143 } },
	},
}
