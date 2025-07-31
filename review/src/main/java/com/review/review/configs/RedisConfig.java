package com.review.review.configs;

import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.Cache;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.interceptor.CacheErrorHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.jedis.JedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext.SerializationPair;
import redis.clients.jedis.exceptions.JedisConnectionException;

import java.time.Duration;

@EnableCaching
@Configuration
public class RedisConfig {

    private static final Logger logger = LoggerFactory.getLogger(RedisConfig.class);

    @Value("${spring.redis.host}")
    private String redisHost;

    @Value("${spring.redis.port}")
    private int redisPort;

    @Bean
    @WithSpan
    public RedisCacheConfiguration defaultCacheConfiguration() {
        return RedisCacheConfiguration.defaultCacheConfig()
                .entryTtl(Duration.ofMinutes(1))
                .disableCachingNullValues()
                .serializeValuesWith(SerializationPair.fromSerializer(new GenericJackson2JsonRedisSerializer()));
    }

    @Bean
    @WithSpan
    public JedisConnectionFactory jedisConnectionFactory() {
        RedisStandaloneConfiguration config = new RedisStandaloneConfiguration();
        config.setHostName(redisHost);
        config.setPort(redisPort);
        return new JedisConnectionFactory(config);
    }

    @Bean
    @WithSpan
    public RedisTemplate<String, Object> redisTemplate() {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(jedisConnectionFactory());
        return template;
    }

    @Bean
    public CacheErrorHandler errorHandler() {
        return new CacheErrorHandler() {
            @Override
            public void handleCacheGetError(RuntimeException exception, Cache cache, Object key) {
                if (exception instanceof JedisConnectionException) {
                    // ✅ Record exception on current span
                    Span currentSpan = Span.current();
                    currentSpan.recordException(exception);
                    currentSpan.setStatus(StatusCode.ERROR, "Redis cache get error");
                    currentSpan.addEvent("cache.error.get");
                    
                    // ✅ Structured logging with correlation
                    logger.error("Redis cache GET error for key: {} in cache: {}", key, cache.getName(), exception);
                }
            }

            @Override
            public void handleCachePutError(RuntimeException exception, Cache cache, Object key, Object value) {
                if (exception instanceof JedisConnectionException) {
                    // ✅ Record exception on current span  
                    Span currentSpan = Span.current();
                    currentSpan.recordException(exception);
                    currentSpan.setStatus(StatusCode.ERROR, "Redis cache put error");
                    currentSpan.addEvent("cache.error.put");
                    
                    // ✅ Structured logging with correlation
                    logger.error("Redis cache PUT error for key: {} in cache: {}", key, cache.getName(), exception);
                }
            }

            @Override
            public void handleCacheEvictError(RuntimeException exception, Cache cache, Object key) {
                if (exception instanceof JedisConnectionException) {
                    // ✅ Record exception on current span
                    Span currentSpan = Span.current();
                    currentSpan.recordException(exception);
                    currentSpan.setStatus(StatusCode.ERROR, "Redis cache evict error");
                    currentSpan.addEvent("cache.error.evict");
                    
                    // ✅ Structured logging with correlation
                    logger.error("Redis cache EVICT error for key: {} in cache: {}", key, cache.getName(), exception);
                }
            }

            @Override
            public void handleCacheClearError(RuntimeException exception, Cache cache) {
                if (exception instanceof JedisConnectionException) {
                    // ✅ Record exception on current span
                    Span currentSpan = Span.current();
                    currentSpan.recordException(exception);
                    currentSpan.setStatus(StatusCode.ERROR, "Redis cache clear error");
                    currentSpan.addEvent("cache.error.clear");
                    
                    // ✅ Structured logging with correlation
                    logger.error("Redis cache CLEAR error in cache: {}", cache.getName(), exception);
                }
            }
        };
    }

}
