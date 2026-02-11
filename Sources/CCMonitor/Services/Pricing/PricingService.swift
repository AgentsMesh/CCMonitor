import Foundation
import Logging

/// 定价服务
/// 三层缓存: 远程 LiteLLM GitHub → 本地缓存文件 → 内嵌 JSON
actor PricingService {
    private static let logger = Logger(label: "com.ccmonitor.PricingService")

    private var database: PricingDatabase = [:]
    private var lastFetchTime: Date?

    /// 数据库中的模型数量
    var databaseCount: Int { database.count }

    /// 获取模型定价
    func getPricing(for modelName: String) -> ModelPricing? {
        // 三级匹配: 精确 → 带前缀精确 → 模糊
        if let exact = database[modelName] {
            return exact
        }

        // 尝试添加 provider 前缀
        for prefix in Constants.defaultProviderPrefixes {
            if let match = database["\(prefix)\(modelName)"] {
                return match
            }
        }

        // 模糊匹配
        let lower = modelName.lowercased()
        for (key, pricing) in database {
            let keyLower = key.lowercased()
            if keyLower.contains(lower) || lower.contains(keyLower) {
                return pricing
            }
        }

        return nil
    }

    /// 加载定价数据（优先远程，回退本地缓存，最后内嵌）
    func loadPricing() async {
        // 1. 尝试远程获取
        if let remote = await fetchRemotePricing() {
            database = remote
            lastFetchTime = Date()
            saveToLocalCache(remote)
            Self.logger.info("Pricing loaded from remote: \(remote.count) models")
            return
        }

        // 2. 尝试本地缓存
        if let cached = loadLocalCache() {
            database = cached
            Self.logger.info("Pricing loaded from local cache: \(cached.count) models")
            return
        }

        // 3. 使用内嵌数据
        database = loadEmbeddedPricing()
        Self.logger.info("Pricing loaded from embedded: \(database.count) models")
    }

    /// 远程获取 LiteLLM 定价
    private func fetchRemotePricing() async -> PricingDatabase? {
        guard let url = URL(string: Constants.liteLLMPricingURL) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }

            // LiteLLM JSON 格式: 顶层对象，每个 key 是模型名，value 是定价
            // 但 value 中还有其他字段（litellm_provider 等），需要容错解码
            let rawDict = try JSONDecoder().decode([String: AnyCodableModelPricing].self, from: data)

            var result: PricingDatabase = [:]
            for (key, wrapper) in rawDict {
                if let pricing = wrapper.toModelPricing() {
                    result[key] = pricing
                }
            }
            return result
        } catch {
            return nil
        }
    }

    // MARK: - 本地缓存

    private var cacheURL: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent(Constants.pricingCacheFileName)
    }

    private func saveToLocalCache(_ db: PricingDatabase) {
        do {
            let data = try JSONEncoder().encode(db)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // 静默失败
        }
    }

    private func loadLocalCache() -> PricingDatabase? {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }

        // 检查缓存过期
        if let attrs = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
           let modDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) > Constants.pricingCacheDuration {
            return nil
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            return try JSONDecoder().decode(PricingDatabase.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - 内嵌定价

    private func loadEmbeddedPricing() -> PricingDatabase {
        guard let url = Bundle.module.url(forResource: "embedded_pricing", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return [:]
        }
        return (try? JSONDecoder().decode(PricingDatabase.self, from: data)) ?? [:]
    }
}

// MARK: - 容错 Codable 包装

/// 容错解码 LiteLLM 的混合格式
private struct AnyCodableModelPricing: Decodable {
    let input_cost_per_token: Double?
    let output_cost_per_token: Double?
    let cache_creation_input_token_cost: Double?
    let cache_read_input_token_cost: Double?
    let max_tokens: Int?
    let max_input_tokens: Int?
    let max_output_tokens: Int?
    let input_cost_per_token_above_200k_tokens: Double?
    let output_cost_per_token_above_200k_tokens: Double?
    let cache_creation_input_token_cost_above_200k_tokens: Double?
    let cache_read_input_token_cost_above_200k_tokens: Double?

    // 忽略所有其他字段
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        input_cost_per_token = try? container.decode(Double.self, forKey: .init("input_cost_per_token"))
        output_cost_per_token = try? container.decode(Double.self, forKey: .init("output_cost_per_token"))
        cache_creation_input_token_cost = try? container.decode(Double.self, forKey: .init("cache_creation_input_token_cost"))
        cache_read_input_token_cost = try? container.decode(Double.self, forKey: .init("cache_read_input_token_cost"))
        max_tokens = try? container.decode(Int.self, forKey: .init("max_tokens"))
        max_input_tokens = try? container.decode(Int.self, forKey: .init("max_input_tokens"))
        max_output_tokens = try? container.decode(Int.self, forKey: .init("max_output_tokens"))
        input_cost_per_token_above_200k_tokens = try? container.decode(Double.self, forKey: .init("input_cost_per_token_above_200k_tokens"))
        output_cost_per_token_above_200k_tokens = try? container.decode(Double.self, forKey: .init("output_cost_per_token_above_200k_tokens"))
        cache_creation_input_token_cost_above_200k_tokens = try? container.decode(Double.self, forKey: .init("cache_creation_input_token_cost_above_200k_tokens"))
        cache_read_input_token_cost_above_200k_tokens = try? container.decode(Double.self, forKey: .init("cache_read_input_token_cost_above_200k_tokens"))
    }

    func toModelPricing() -> ModelPricing? {
        // 必须至少有输入或输出价格
        guard input_cost_per_token != nil || output_cost_per_token != nil else { return nil }
        return ModelPricing(
            input_cost_per_token: input_cost_per_token,
            output_cost_per_token: output_cost_per_token,
            cache_creation_input_token_cost: cache_creation_input_token_cost,
            cache_read_input_token_cost: cache_read_input_token_cost,
            max_tokens: max_tokens,
            max_input_tokens: max_input_tokens,
            max_output_tokens: max_output_tokens,
            input_cost_per_token_above_200k_tokens: input_cost_per_token_above_200k_tokens,
            output_cost_per_token_above_200k_tokens: output_cost_per_token_above_200k_tokens,
            cache_creation_input_token_cost_above_200k_tokens: cache_creation_input_token_cost_above_200k_tokens,
            cache_read_input_token_cost_above_200k_tokens: cache_read_input_token_cost_above_200k_tokens
        )
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
