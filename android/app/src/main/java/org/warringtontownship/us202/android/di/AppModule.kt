package org.warringtontownship.us202.android.di

import android.content.Context
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.Cache
import okhttp3.CacheControl
import okhttp3.OkHttpClient
import org.warringtontownship.us202.android.data.network.ConnectorApiService
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(@ApplicationContext context: Context): OkHttpClient =
        OkHttpClient.Builder()
            .cache(Cache(File(context.cacheDir, "http_cache"), 10L * 1024 * 1024))
            .addInterceptor { chain ->
                // Cell coverage on the trail is unreliable: if the network is down,
                // fall back to the cached trail data no matter how stale it is.
                try {
                    chain.proceed(chain.request())
                } catch (e: IOException) {
                    val offlineRequest = chain.request().newBuilder()
                        .cacheControl(
                            CacheControl.Builder()
                                .onlyIfCached()
                                .maxStale(365, TimeUnit.DAYS)
                                .build()
                        )
                        .build()
                    chain.proceed(offlineRequest)
                }
            }
            .build()

    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit = Retrofit.Builder()
        .baseUrl("https://trails.warringtoneac.org/us-202/")
        .client(okHttpClient)
        .addConverterFactory(GsonConverterFactory.create())
        .build()

    @Provides
    @Singleton
    fun provideConnectorApiService(retrofit: Retrofit): ConnectorApiService =
        retrofit.create(ConnectorApiService::class.java)
}
