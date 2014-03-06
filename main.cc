// Author by Yusong Gao (yusong.gao@gmail.com)
#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <stdlib.h>
#include <sys/time.h>



using namespace std;

struct trie_node_t {
	bool ff;
	trie_node_t *chd[2];

	trie_node_t(bool ff = false) {
		this->ff = ff;
		this->chd[0] = this->chd[1] = NULL;
	}
};


trie_node_t *new_node()
{
	return new trie_node_t;
}

struct trie_t {
	int size;
	trie_node_t *root;

	trie_t(int size = 0) {
		this->size = size;
		this->root = NULL;
	}
};

void delete_nodes(trie_node_t *root)
{
	if (NULL == root) {
		return;
	}
	delete_nodes(root->chd[0]);
	delete_nodes(root->chd[1]);
	delete root->chd[0];
	delete root->chd[1];
}

void destroy_trie(trie_t &trie)
{
	trie.size = 0;

	delete_nodes(trie.root);
	delete trie.root;
	trie.root = NULL;
}



int insert_trie_1(uint32_t bits, int len, trie_node_t **root)
{
	if (NULL == *root) {
		*root = new_node();
		return insert_trie_1(bits, len, root) + 1;
	}

	if ((*root)->ff) {
		return 0;
	}

	if (0 == len) {
		(*root)->ff = true;
		return 0;
	}

	return insert_trie_1(bits, len - 1, &((*root)->chd[(bits >> (len -1)) & 1]));

}

void insert_trie(uint32_t bits, int len, trie_t &trie_t)
{
	int ret = insert_trie_1(bits, len, &trie_t.root);
	trie_t.size += ret;
}

bool find_trie_1(uint32_t bits, int len, trie_node_t *root)
{
	if (NULL == root) {
		return false;
	}

	if (root->ff)
		return true;

	return find_trie_1(bits, len - 1, root->chd[(bits >> (len - 1)) & 1]);
}

bool find_trie(uint32_t bits, int len, const trie_t &trie_t)
{
	return find_trie_1(bits, len, trie_t.root);
}

void gen_cidr(uint32_t &ip1, uint32_t &ip2, uint32_t &ip3, uint32_t &ip4, uint32_t &mask)
{
	ip1 = rand() % 256;
	ip2 = rand() % 256;
	ip3 = rand() % 256; 
	ip4 = rand() % 256;
	mask = rand() % 33;
}

int main()
{


	srand(time(NULL));

	int n, m = 10000000;

	while (scanf("%d", &n) == 1) {
		trie_t trie;
		uint32_t ip1, ip2, ip3, ip4, mask;
		for (int i = 0; i < n; i++) {
			//printf("%d.%d.%d.%d/%d\n", ip1, ip2, ip3, ip4, mask);
			gen_cidr(ip1, ip2, ip3, ip4, mask);
			insert_trie((ip1 << 24) | (ip2 << 16) | (ip3 << 8) | ip4, mask, trie);
		}
		printf("size: %d\n", trie.size);
		gen_cidr(ip1, ip2, ip3, ip4, mask);
		struct timeval t1,t2;
		bool ret;
		gettimeofday(&t1, NULL);
		for (int i = 0; i < m; i++) {
			ret = find_trie((ip1 << 24) | (ip2 << 16) | (ip3 << 8) | ip4, mask, trie);
		}
		gettimeofday(&t2, NULL);
    	long long int t_us = t2.tv_sec - t1.tv_sec + t2.tv_usec - t1.tv_usec;
		
		printf("ret: %d time: %lld, %.2f\n", ret, t_us, m / (t_us / 1000000.0));
		destroy_trie(trie);
	}

	return 0;
}
