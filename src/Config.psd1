@{
    Terminal49 = @{
        BaseUrl = 'https://api.terminal49.com/v2'
        # API key is NOT stored here. It is read from environment variable T49_API_KEY.
    }
    Freightos = @{
        BaseUrl = 'https://ship.freightos.com/api/shippingCalculator'
        # No API key needed for public marketplace estimates.
        RateLimitPerHour = 100
    }
}
